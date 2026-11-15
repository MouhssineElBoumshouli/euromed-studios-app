-- I3 · Users and roles: an admin changes someone's roles, approval
-- scopes, clubs, or turns their account off. One function does it all in
-- one step, checks every rule, and writes the activity log (P-11).

alter table public.profiles add column active boolean not null default true;

-- A turned-off account counts as signed out everywhere: no profile, so
-- no role, no booking, no access (every rule goes through me()).
create or replace function public.me() returns public.profiles
language sql stable security definer set search_path = public as $$
  select * from public.profiles where id = auth.uid() and active
$$;

create or replace function public.role_label(r text) returns text
language sql immutable as $$
  select case r
    when 'student' then 'Étudiant·e'
    when 'professor' then 'Enseignant·e'
    when 'communication' then 'Communication'
    when 'clubRepresentative' then 'Représentant·e de club'
    when 'externalClient' then 'Client externe'
    when 'entityApprover' then 'Validateur niveau 1'
    when 'studioManager' then 'Responsable des Studios'
    when 'regisseur' then 'Régisseur'
    when 'admin' then 'Administrateur'
    else r end
$$;

create or replace function public.set_person_access(
  p_slug text, p_roles text[], p_scopes jsonb, p_clubs text[], p_active boolean
) returns void
language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.me();
  prev public.profiles;
  allowed text[] := array['student','professor','communication','clubRepresentative','externalClient',
                          'entityApprover','studioManager','regisseur','admin'];
  v_roles text[];
  v_scopes jsonb := '[]';
  v_clubs text[] := '{}';
  added text[];
  removed text[];
  parts text[] := '{}';
  s jsonb;
begin
  if not public.has_role(me, 'admin') then raise exception 'not_allowed'; end if;
  select * into prev from public.profiles where slug = p_slug for update;
  if prev.id is null then raise exception 'unknown_person'; end if;

  select coalesce(array_agg(distinct r order by r), '{}') into v_roles from unnest(p_roles) r;
  if cardinality(v_roles) = 0 then raise exception 'no_role'; end if;
  if not v_roles <@ allowed then raise exception 'bad_role'; end if;

  -- Approval scopes only for level-1 approvers; clubs only for club reps.
  if 'entityApprover' = any (v_roles) then
    if jsonb_typeof(coalesce(p_scopes, '[]')) <> 'array' then raise exception 'bad_scope'; end if;
    for s in select * from jsonb_array_elements(coalesce(p_scopes, '[]')) loop
      if coalesce(s->>'type', '') not in ('student','club','professor','communication','external') then
        raise exception 'bad_scope';
      end if;
    end loop;
    v_scopes := coalesce(p_scopes, '[]');
    if jsonb_array_length(v_scopes) = 0 then raise exception 'scope_required'; end if;
  end if;
  if 'clubRepresentative' = any (v_roles) then
    v_clubs := coalesce(p_clubs, '{}');
    if cardinality(v_clubs) = 0 then raise exception 'club_required'; end if;
  end if;

  -- No admin can lock themselves out, and one active admin always remains.
  if prev.id = me.id and (not p_active or not ('admin' = any (v_roles))) then
    raise exception 'self_lockout';
  end if;
  if (not p_active or not ('admin' = any (v_roles)))
     and 'admin' = any (prev.roles)
     and not exists (select 1 from public.profiles
                     where profiles.active and 'admin' = any (profiles.roles) and profiles.id <> prev.id) then
    raise exception 'last_admin';
  end if;

  update public.profiles
    set roles = v_roles, approver_scopes = v_scopes, club_ids = v_clubs, active = p_active
    where id = prev.id;

  select coalesce(array_agg(x), '{}') into added from unnest(v_roles) x where not x = any (prev.roles);
  select coalesce(array_agg(x), '{}') into removed from unnest(prev.roles) x where not x = any (v_roles);
  if cardinality(added) > 0 then
    parts := parts || ('+ ' || (select string_agg(public.role_label(x), ', ') from unnest(added) x));
  end if;
  if cardinality(removed) > 0 then
    parts := parts || ('− ' || (select string_agg(public.role_label(x), ', ') from unnest(removed) x));
  end if;
  if v_scopes is distinct from prev.approver_scopes then parts := parts || 'périmètre de validation modifié'::text; end if;
  if v_clubs is distinct from prev.club_ids then parts := parts || 'clubs modifiés'::text; end if;
  if p_active is distinct from prev.active then
    parts := parts || (case when p_active then 'compte réactivé' else 'compte désactivé' end)::text;
  end if;
  if cardinality(parts) = 0 then return; end if;

  perform public.audit(
    case when p_active is distinct from prev.active
         then case when p_active then 'accountEnabled' else 'accountDisabled' end
         else 'rolesChanged' end,
    'person', prev.slug,
    prev.first_name || ' ' || prev.last_name || ' : ' || array_to_string(parts, ' · '),
    jsonb_build_object('before', jsonb_build_object('roles', prev.roles, 'scopes', prev.approver_scopes,
                                                    'clubs', prev.club_ids, 'active', prev.active),
                       'after', jsonb_build_object('roles', v_roles, 'scopes', v_scopes,
                                                   'clubs', v_clubs, 'active', p_active)));
end $$;
revoke execute on function public.set_person_access(text, text[], jsonb, text[], boolean) from public, anon;
grant execute on function public.set_person_access(text, text[], jsonb, text[], boolean) to authenticated;
