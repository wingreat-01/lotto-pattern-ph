-- LottoPattern PH: server-enforced trial credits and premium access.
-- Run with Supabase CLI migrations or paste into the SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.trial_eligibility (
  id uuid primary key default gen_random_uuid(),
  google_subject text not null unique,
  first_user_id uuid not null,
  first_trial_started_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.user_entitlements (
  user_id uuid primary key references auth.users(id) on delete cascade,
  trial_started_at timestamptz,
  trial_expires_at timestamptz,
  credits_remaining integer not null default 20 check (credits_remaining >= 0),
  lifetime_unlocked boolean not null default false,
  updated_at timestamptz not null default now(),
  constraint valid_trial_window check (
    (trial_started_at is null and trial_expires_at is null) or
    (trial_started_at is not null and trial_expires_at = trial_started_at + interval '5 days')
  )
);

create table if not exists public.generation_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  request_id uuid not null,
  combinations_charged integer not null check (combinations_charged between 1 and 10),
  created_at timestamptz not null default now(),
  unique (user_id, request_id)
);

create table if not exists public.play_purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id text not null,
  purchase_token_hash text not null unique,
  order_id text,
  purchase_state text not null check (purchase_state in ('verified','refunded','revoked')),
  verified_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.trial_eligibility enable row level security;
alter table public.user_entitlements enable row level security;
alter table public.generation_ledger enable row level security;
alter table public.play_purchases enable row level security;

-- Users can read their own entitlement only. No client writes are allowed.
drop policy if exists "read own entitlement" on public.user_entitlements;
create policy "read own entitlement" on public.user_entitlements
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "read own generation ledger" on public.generation_ledger;
create policy "read own generation ledger" on public.generation_ledger
  for select to authenticated using (user_id = auth.uid());

revoke all on public.trial_eligibility from anon, authenticated;
revoke insert, update, delete on public.user_entitlements from anon, authenticated;
revoke insert, update, delete on public.generation_ledger from anon, authenticated;
revoke all on public.play_purchases from anon, authenticated;
grant select on public.user_entitlements, public.generation_ledger to authenticated;

-- Called only by a signed-in user. Starts the trial on the first successful generation,
-- and permanently retains the Google provider subject after account deletion.
create or replace function public.consume_generation_credits(
  p_count integer,
  p_request_id uuid
) returns jsonb
language plpgsql security definer set search_path = public, auth, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_google_subject text;
  v_ent public.user_entitlements%rowtype;
  v_now timestamptz := now();
begin
  if v_uid is null then raise exception 'authentication_required' using errcode = '28000'; end if;
  if p_count is null or p_count < 1 or p_count > 10 then
    raise exception 'invalid_generation_count' using errcode = '22023';
  end if;
  if p_request_id is null then raise exception 'request_id_required' using errcode = '22023'; end if;

  -- Idempotency: a retried request never charges twice.
  if exists(select 1 from public.generation_ledger where user_id = v_uid and request_id = p_request_id) then
    select * into v_ent from public.user_entitlements where user_id = v_uid;
    return jsonb_build_object('ok', true, 'duplicate', true,
      'credits_remaining', coalesce(v_ent.credits_remaining, 20),
      'trial_expires_at', v_ent.trial_expires_at,
      'lifetime_unlocked', coalesce(v_ent.lifetime_unlocked, false));
  end if;

  insert into public.user_entitlements(user_id) values(v_uid) on conflict (user_id) do nothing;
  select * into v_ent from public.user_entitlements where user_id = v_uid for update;

  if v_ent.lifetime_unlocked then
    insert into public.generation_ledger(user_id, request_id, combinations_charged)
      values(v_uid, p_request_id, p_count);
    return jsonb_build_object('ok', true, 'lifetime_unlocked', true,
      'credits_remaining', v_ent.credits_remaining, 'trial_expires_at', v_ent.trial_expires_at);
  end if;

  if v_ent.trial_started_at is null then
    select i.provider_id into v_google_subject
      from auth.identities i
      where i.user_id = v_uid and i.provider = 'google'
      limit 1;
    if v_google_subject is null then
      raise exception 'google_sign_in_required' using errcode = '42501';
    end if;

    insert into public.trial_eligibility(google_subject, first_user_id)
      values(v_google_subject, v_uid)
      on conflict (google_subject) do nothing;

    if not exists (
      select 1 from public.trial_eligibility e
      where e.google_subject = v_google_subject and e.first_user_id = v_uid
    ) then
      raise exception 'trial_already_used' using errcode = 'P0001';
    end if;

    update public.user_entitlements
      set trial_started_at = v_now, trial_expires_at = v_now + interval '5 days', updated_at = v_now
      where user_id = v_uid
      returning * into v_ent;
  end if;

  if v_ent.trial_expires_at <= v_now then
    raise exception 'trial_expired' using errcode = 'P0001';
  end if;
  if v_ent.credits_remaining < p_count then
    raise exception 'insufficient_credits' using errcode = 'P0001';
  end if;

  update public.user_entitlements
    set credits_remaining = credits_remaining - p_count, updated_at = v_now
    where user_id = v_uid returning * into v_ent;
  insert into public.generation_ledger(user_id, request_id, combinations_charged)
    values(v_uid, p_request_id, p_count);

  return jsonb_build_object('ok', true, 'duplicate', false,
    'credits_remaining', v_ent.credits_remaining,
    'trial_started_at', v_ent.trial_started_at,
    'trial_expires_at', v_ent.trial_expires_at,
    'lifetime_unlocked', v_ent.lifetime_unlocked);
end;
$$;

create or replace function public.get_my_entitlement()
returns jsonb language plpgsql security definer set search_path = public
as $$
declare v_uid uuid := auth.uid(); v_ent public.user_entitlements%rowtype;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode = '28000'; end if;
  insert into public.user_entitlements(user_id) values(v_uid) on conflict (user_id) do nothing;
  select * into v_ent from public.user_entitlements where user_id = v_uid;
  return jsonb_build_object(
    'credits_remaining', v_ent.credits_remaining,
    'trial_started_at', v_ent.trial_started_at,
    'trial_expires_at', v_ent.trial_expires_at,
    'trial_started', v_ent.trial_started_at is not null,
    'trial_active', v_ent.trial_expires_at > now(),
    'lifetime_unlocked', v_ent.lifetime_unlocked
  );
end;
$$;

create or replace function public.check_premium_access()
returns jsonb language plpgsql security definer set search_path = public
as $$
declare v_uid uuid := auth.uid(); v_ent public.user_entitlements%rowtype;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode = '28000'; end if;
  select * into v_ent from public.user_entitlements where user_id = v_uid;
  if not found then return jsonb_build_object('allowed', false, 'reason', 'trial_not_started'); end if;
  if v_ent.lifetime_unlocked then return jsonb_build_object('allowed', true, 'reason', 'lifetime'); end if;
  if v_ent.trial_expires_at is not null and v_ent.trial_expires_at > now() then
    return jsonb_build_object('allowed', true, 'reason', 'trial', 'expires_at', v_ent.trial_expires_at);
  end if;
  return jsonb_build_object('allowed', false, 'reason', case when v_ent.trial_started_at is null then 'trial_not_started' else 'trial_expired' end);
end;
$$;

revoke all on function public.consume_generation_credits(integer, uuid) from public, anon;
revoke all on function public.get_my_entitlement() from public, anon;
revoke all on function public.check_premium_access() from public, anon;
grant execute on function public.consume_generation_credits(integer, uuid) to authenticated;
grant execute on function public.get_my_entitlement() to authenticated;
grant execute on function public.check_premium_access() to authenticated;

-- Purchase verification backend must update entitlements only after Google Play API verification.
-- Do not grant lifetime access from a client-provided boolean.
