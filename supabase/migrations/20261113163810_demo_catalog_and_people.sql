insert into public.studios (id, name, room_id, bookable) values
 ('plateau_tv','Plateau TV','area2',true),('radio','Euromed Radio','area2',true),
 ('podcast','Studio Podcast','area1',true),('chroma','Chroma Key Studio','area3',true),
 ('photo','Studio Photographie','area3',true),('pedago','Studio Pédagogique','area4',true),
 ('speedmooc','SpeedMOOC','area4',true),('montage','Espace Montage','montage',true),
 ('regie_tv','Régie TV','ctrl1',false),('salon_vip','Salon VIP','area1',false);

insert into public.equipment (id, name, stock) values
 ('kit_cam','Kit caméra mobile',3),('lav_mic','Micro-cravate sans fil',3),
 ('hand_mic','Micro main',4),('led_kit','Kit éclairage LED',2);

-- Fictional demo people (no real names). One shared demo password, set by
-- the app's demo sign-in buttons; replaced by UEMF sign-in in production.
do $$
declare
  r record;
  uid uuid;
begin
  for r in select * from (values
    ('yasmine','Yasmine','Mansouri','Étudiante · EIDIA','eidia', array['student'], array[]::text[], '[]'::jsonb),
    ('adam','Adam','Kettani','Étudiant · EMADU · Club Audiovisuel','emadu', array['student','clubRepresentative'], array['club_av'], '[]'::jsonb),
    ('rami','Driss','Rami','Enseignant-chercheur · EIDIA','eidia', array['professor'], array[]::text[], '[]'::jsonb),
    ('nadia','Nadia','Ennaji','Équipe Communication',null, array['communication'], array[]::text[], '[]'::jsonb),
    ('omar','Omar','Berrada','Studio Lumen (fictif) · client externe',null, array['externalClient'], array[]::text[], '[]'::jsonb),
    ('amrani','Karim','Amrani','Responsable Vie Étudiante',null, array['entityApprover'], array[]::text[], '[{"type":"student"},{"type":"club"}]'::jsonb),
    ('benjelloun','Hind','Benjelloun','Directrice · EIDIA','eidia', array['entityApprover','professor'], array[]::text[], '[{"type":"professor","establishment_id":"eidia"}]'::jsonb),
    ('lahlou','Youssef','Lahlou','Direction de la Communication',null, array['entityApprover'], array[]::text[], '[{"type":"communication"}]'::jsonb),
    ('fassi','Leila','Fassi','Vice-Présidence Exécutive',null, array['entityApprover'], array[]::text[], '[{"type":"external"}]'::jsonb),
    ('tazi','Mehdi','Tazi','Responsable des Studios',null, array['studioManager'], array[]::text[], '[]'::jsonb),
    ('haddad','Samir','Haddad','Régisseur · Euromed Studios',null, array['regisseur'], array[]::text[], '[]'::jsonb),
    ('idrissi','Sara','Idrissi','Administratrice · Euromed Studios',null, array['admin'], array[]::text[], '[]'::jsonb)
  ) as t(slug, first_name, last_name, title, est, roles, clubs, scopes)
  loop
    uid := gen_random_uuid();
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, email_change, email_change_token_new, recovery_token)
    values ('00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated',
      r.slug || '@demo.euromed-studios.test',
      extensions.crypt('Studio-Demo-2026!', extensions.gen_salt('bf')), now(),
      '{"provider":"email","providers":["email"]}', jsonb_build_object('slug', r.slug), now(), now(), '', '', '', '');
    insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
    values (gen_random_uuid(), uid, uid::text,
      jsonb_build_object('sub', uid::text, 'email', r.slug || '@demo.euromed-studios.test', 'email_verified', true),
      'email', now(), now(), now());
    insert into public.profiles (id, slug, first_name, last_name, title, establishment_id, roles, club_ids, approver_scopes)
    values (uid, r.slug, r.first_name, r.last_name, r.title, r.est, r.roles, r.clubs, r.scopes);
  end loop;
end $$;
