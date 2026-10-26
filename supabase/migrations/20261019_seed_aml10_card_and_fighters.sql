-- AML seed: AML 10 card (Korhogo) + AML fighters from the athlete info sheets.
-- Idempotent: can be re-run safely (fighters upserted by slug, fights matched by pair).
-- Run in the Supabase SQL Editor AFTER the earlier migrations.
begin;

-- Amateur record (the app stores the professional record in wins/losses/draws).
alter table public.fighter_stats add column if not exists amateur_wins   integer not null default 0 check (amateur_wins   >= 0);
alter table public.fighter_stats add column if not exists amateur_losses integer not null default 0 check (amateur_losses >= 0);
alter table public.fighter_stats add column if not exists amateur_draws  integer not null default 0 check (amateur_draws  >= 0);

do $seed$
declare
  v_comp   uuid;
  v_event  uuid;
  -- Poster: 29 août 2026, 18h, Korhogo (Côte d'Ivoire = UTC+0). Change here if the date moves.
  v_starts timestamptz := timestamptz '2026-08-29 18:00:00+00';
  v_added  integer;
  v_other  integer;
  v_people integer;
begin
  -- 1. AML competition ----------------------------------------------------
  select c.id into v_comp from public.competitions c where c.is_aml order by c.is_active desc, c.created_at limit 1;
  if v_comp is null then
    select c.id into v_comp from public.competitions c
     where lower(c.slug) = 'aml' or c.name ilike '%african mma%' order by c.created_at limit 1;
  end if;
  if v_comp is null then
    insert into public.competitions(name, slug, short_name, country_code, is_aml, is_active)
    values ('African MMA League', 'aml', 'AML', 'CI', true, true) returning id into v_comp;
  else
    update public.competitions set is_aml = true where id = v_comp;
  end if;

  -- 2. AML weight categories (names as on the athlete sheets) ---------------
  insert into public.weight_categories(name, gender, min_weight_kg, max_weight_kg) values
    ('Flyweight (F)',     'female', 53, 57),
    ('Bantamweight (F)',  'female', 57, 61),
    ('Lightweight (F)',   'female', 66, 70),
    ('Bantamweight',      'male',   57, 61),
    ('Featherweight',     'male',   60, 66),
    ('Lightweight',       'male',   66, 70),
    ('Welterweight',      'male',   70, 77),
    ('Middleweight',      'male',   82, 87),
    ('Heavyweight',       'male',   90, null)
  on conflict (name) do update
    set gender = excluded.gender, min_weight_kg = excluded.min_weight_kg, max_weight_kg = excluded.max_weight_kg;

  -- 3. Fighters ------------------------------------------------------------
  create temp table _aml_seed (
    slug text, first_name text, last_name text, nickname text, country_code text, category text, style text,
    dob date, weight_kg numeric, height_cm numeric, reach_cm numeric,
    am_w int, am_l int, am_d int, pro_w int, pro_l int, pro_d int
  ) on commit drop;

  insert into _aml_seed values
  ('mary-victory-nde-bih', 'Mary Victory', 'Nde Bih', 'L’ARME FATALE OU THE LETHAL WEAPON', 'CM', 'Flyweight (F)', 'Striking', '2001-09-19'::date, 57, 160, 168, null, null, null, 0, 1, 0),
  ('rahima-chikh-amine', 'Rahima', 'Chikh Amine', 'THE CRUSHER', 'DZ', 'Flyweight (F)', 'Striking', '1999-02-12'::date, 57, 170, 176, null, null, null, 0, 1, 0),
  ('zineb-hassoune', 'Zineb', 'Hassoune', 'DIVA ZINEB', 'MA', 'Flyweight (F)', 'Grappling', '2001-01-19'::date, 59, 153, 160, null, null, null, 1, 0, 0),
  ('symphorose-kiala', 'Symphorose', 'Kiala', 'CINKO', 'CD', 'Flyweight (F)', 'Striking', '2002-03-28'::date, 57, 172, 180, 0, 0, 0, 1, 0, 0),
  ('mame-diarra-thiaw', 'Mame Diarra', 'Thiaw', 'COBRA NOIR', 'SN', 'Lightweight (F)', 'Striking', '2006-08-04'::date, 70, 175, 181, 3, 1, 0, 0, 0, 0),
  ('jeanne-haba-tohon', 'Jeanne', 'Haba Tohon', 'JEANNE', 'CI', 'Lightweight (F)', 'Striking', '1997-07-04'::date, 70, 165, 170, 0, 2, 0, 0, 0, 0),
  ('yasmine-kefane', 'Yasmine', 'Kefane', 'PSYCHO FIGHTER', 'DZ', 'Bantamweight (F)', 'Grappling', '1998-12-19'::date, 59, 162, 168, null, null, null, 1, 0, 0),
  ('winifred-peter', 'Winifred', 'Peter', 'KAMI', 'NG', 'Bantamweight (F)', 'Striking', '2003-11-24'::date, 52, 162, 154, null, null, null, 0, 1, 0),
  ('sita-traore-kongo', 'Sita', 'Traore Kongo', 'KING KONG', 'CI', 'Bantamweight (F)', 'Striking', '1996-06-16'::date, 55, 160, 168, 1, 0, 0, null, null, null),
  ('mariam-ouattara', 'Mariam', 'Ouattara', null, 'CI', 'Bantamweight (F)', 'Striking', '2001-03-04'::date, 59, 160, 170, 0, 1, 0, null, null, null),
  ('tiene-fofana', 'Tiéné', 'Fofana', 'LA TIGRESSE', 'CI', 'Lightweight (F)', 'Striking', '2002-01-01'::date, 70, 150, 172, 1, 3, 0, null, null, null),
  ('fatima-kourouma', 'Fatima', 'Kourouma', 'LA GUERRIERE DE 224', 'GN', 'Lightweight (F)', 'Striking', '2005-02-16'::date, 70, 168, 170, 1, 0, 0, null, null, null),
  ('adam-diapkile', 'Adam', 'Diapkile', null, 'ML', 'Lightweight (F)', 'Striking', '2004-08-14'::date, 64, 170, 180, 3, 0, 0, null, null, null),
  ('salimata-honogo', 'Salimata', 'Honogo', 'ALMUHARIB', 'CI', 'Lightweight (F)', 'Striking', null::date, 70, 170, 175, 0, 2, 0, null, null, null),
  ('naomie-lopoua', 'Naomie', 'Lopoua', 'WARRIOR WOMAN', 'CI', 'Bantamweight (F)', 'Striking', '2001-03-14'::date, 60, 168, 169, 1, 0, 0, null, null, null),
  ('bertille-pakode', 'Bertille', 'Pakode', 'BERTINOUSH', 'BF', 'Bantamweight (F)', 'Striking', null::date, 60, 170, 180, 2, 1, 0, null, null, null),
  ('fanny-konate', 'Fanny', 'Konate', 'LE KYF OF GOD', 'CI', 'Bantamweight (F)', 'Striking', '1992-07-11'::date, 65, 168, 172, 0, 3, 0, null, null, null),
  ('yacouba-sare', 'Yacouba', 'Sare', 'FORCE SPECIALE', 'CI', 'Welterweight', 'Striking', '2002-11-05'::date, 77, 180, 185, 3, 0, 0, 2, 0, 0),
  ('salif-diakite', 'Salif', 'Diakite', 'MAMBA NOIR', 'CI', 'Heavyweight', 'Striking', null::date, 100, 186, 204, 1, 1, 0, 2, 0, 0),
  ('mohammed-abidi', 'Mohammed', 'Abidi', 'LIGHTNING ONI', 'DZ', 'Welterweight', 'Grappling', '1993-08-23'::date, 74, 184, 183, null, null, null, 1, 1, 0),
  ('hamza-gourtite', 'Hamza', 'Gourtite', 'Evo Champion', 'MA', 'Heavyweight', 'Grappling', '1999-07-16'::date, 100, 186, 195, null, null, null, 0, 1, 0),
  ('abdallah-mohamed', 'Abdallah', 'Mohamed', 'SUPER SOLDIER', 'EG', 'Lightweight', 'Striking', '1997-10-01'::date, 70, 176, 188, null, null, null, 2, 0, 0),
  ('pelajah-osoba', 'Pelajah', 'Osoba', 'THE BRIDGE', 'NG', 'Lightweight', 'Striking', '1997-01-12'::date, 70, 180, 198, null, null, null, 0, 1, 0),
  ('soufiane-el-kalbi', 'Soufiane', 'El Kalbi', 'THE KILLER', 'MA', 'Featherweight', 'Striking', '2001-02-04'::date, 66, 180, 185, null, null, null, 1, 1, 0),
  ('souleymane-sidibe', 'Souleymane', 'Sidibé', 'NEGRO SOLIDE', 'CI', 'Featherweight', 'Striking', '2003-01-23'::date, 65, 177, 187, 5, 2, 0, 1, 0, 0),
  ('taofeek-rokibu', 'Taofeek', 'Rokibu', 'LE DOZO', 'NG', 'Welterweight', 'Striking', '1996-07-18'::date, 77, 184, 199, 5, 3, 0, 1, 1, 0),
  ('amine-mamdouhi', 'Amine', 'Mamdouhi', 'RICO', 'MA', 'Welterweight', 'Striking', '2001-07-19'::date, 77, 186, 183, null, null, null, 0, 1, 0),
  ('joseph-bessala-owono', 'Joseph', 'Bessala Owono', 'ZAPATA MOTIVATION', 'CM', 'Welterweight', 'Striking', '2001-03-28'::date, 77, 180, 186, null, null, null, 1, 0, 0),
  ('saleh-kapenda-ken', 'Saleh', 'Kapenda Ken', 'MARIHA', 'CD', 'Welterweight', 'Striking', '2004-03-20'::date, 77, 185, 195, null, null, null, 0, 1, 0),
  ('romeo-tsla-nga', 'Romeo', 'Tsla Nga', 'ROMEO', 'CM', 'Middleweight', 'Striking', '2003-12-27'::date, 84, 190, 198, null, null, null, 1, 0, 0),
  ('enoch-sackey', 'Enoch', 'Sackey', 'BLUENAVY DIVER', 'GH', 'Middleweight', 'Striking', '1991-05-20'::date, 84, 178, 183, null, null, null, 0, 1, 0),
  ('aboubacar-sanogo', 'Aboubacar', 'Sanogo', 'LE PYTHON', 'CI', 'Welterweight', 'Striking', '1999-06-08'::date, 59, 153, 160, 7, 0, 0, 0, 2, 0),
  ('othmane-nadji', 'Othmane', 'Nadji', null, 'DZ', 'Welterweight', 'Striking', '2003-02-02'::date, 77, 183, 185, null, null, null, 0, 1, 0),
  ('william-essirard', 'William', 'Essirard', 'LE LEZZARD', 'CI', 'Featherweight', 'Grappling', '1989-11-18'::date, 66, 170, 178, 2, 0, 0, 0, 1, 0),
  ('pierre-eric-fofe', 'Pierre Éric', 'Fofe', 'BILLY BLACK', 'CM', 'Heavyweight', 'Grappling', '1993-12-06'::date, 100, 185, 190, null, null, null, 1, 0, 0),
  ('roger-moassong', 'Roger', 'Moassong', 'LE GLADIATOR', 'CI', 'Heavyweight', 'Striking', '1996-04-05'::date, 94, 173, 177, null, null, null, 0, 1, 0),
  ('mohamed-drame', 'Mohamed', 'Drame', 'MOHAMED ALI', 'CI', 'Featherweight', 'Striking', '2005-05-04'::date, 63, 177, 182, 1, 1, 0, null, null, null),
  ('charles-dohou', 'Charles', 'Dohou', 'CHARLY ZIBONG', 'BJ', 'Featherweight', 'Striking', '1996-11-04'::date, 65, 173, 180, 0, 1, 0, null, null, null),
  ('mouctar-diallo', 'Mouctar', 'Diallo', 'BASSOURA DALEIN', 'GN', 'Welterweight', 'Striking', '1987-01-01'::date, 72, 170, 197, 2, 3, 0, null, null, null),
  ('nordan-zanzi-beni', 'Nordan', 'Zanzi Beni', 'GRAND GORILLE', 'CG', 'Welterweight', 'Striking', '1996-10-29'::date, 77, 183, 188, 0, 1, 0, null, null, null),
  ('issouf-kone', 'Issouf', 'Kone', 'AKACH CAILLOUX', 'CI', 'Heavyweight', 'Striking', '1994-04-30'::date, 117, 178, 183, 2, 1, 0, 0, 1, 0),
  ('axel-iridjie', 'Axel', 'Iridjie', 'GUERRIER BADIEGLOH', 'CI', 'Middleweight', 'Grappling', '1999-05-11'::date, 90, 180, 190, 6, 1, 0, 1, 0, 0),
  ('amadou-bah', 'Amadou', 'Bah', null, 'SN', 'Middleweight', 'Striking', null::date, 84, 186, 192, 3, 1, 0, 0, 1, 0),
  ('solo-bouare', 'Solo', 'Bouare', 'BOUARE', 'ML', 'Welterweight', 'Striking', '2002-09-29'::date, 70, 175, 200, 1, 1, 0, null, null, null),
  ('christophe-kpele', 'Christophe', 'Kpele', 'LE SCORPION', 'CI', 'Welterweight', 'Grappling', '2000-12-11'::date, 74, 176, 200, 2, 4, 0, 0, 1, 0),
  ('louis-joseph-curtis', 'Louis Joseph', 'Curtis', 'LEONIDAS', 'CI', 'Welterweight', 'Striking', null::date, 77, 184, 190, 0, 1, 0, null, null, null),
  ('ibrahim-ouattara', 'Ibrahim', 'Ouattara', 'AGBATOKO', 'CI', 'Welterweight', 'Striking', '1991-03-13'::date, 77, 189, 193, 1, 1, 0, null, null, null),
  ('ousmane-toure', 'Ousmane', 'Toure', null, 'CI', 'Welterweight', 'Striking', '1993-10-05'::date, 72, 187, 198, 1, 1, 0, null, null, null),
  ('faridou-guene', 'Faridou', 'Guene', null, 'BF', 'Welterweight', 'Striking', '1998-12-11'::date, 75, 180, 187, 2, 0, 0, null, null, null),
  ('mohamed-kone', 'Mohamed', 'Kone', 'MK LA LEGENDE', 'CI', 'Featherweight', 'Striking', '1996-10-03'::date, 63, 184, 186, 2, 2, 0, null, null, null),
  ('mohamed-camara', 'Mohamed', 'Camara', null, 'CI', 'Featherweight', 'Striking', '2003-12-31'::date, 63, 178, 186, 1, 3, 0, null, null, null),
  ('cheick-berete', 'Cheick', 'Berete', 'LE COBRA', 'CI', 'Featherweight', 'Striking', '1997-11-15'::date, 66, 177, 170, 0, 2, 0, null, null, null),
  ('jean-kevin-lelou', 'Jean Kevin', 'Lelou', 'L’ENFANT TERRIBLE DE BINGERVILLE', 'CI', 'Bantamweight', 'Striking', null::date, 60, 180, 182, 3, 1, 0, null, null, null),
  ('sidi-koureich', 'Sidi', 'Koureich', null, 'CI', 'Bantamweight', 'Striking', null::date, 60, 173, 180, 0, 1, 0, null, null, null),
  ('abdoulaye-cisse', 'Abdoulaye', 'Cisse', 'SAMSON', 'CI', 'Welterweight', 'Striking', '1999-08-03'::date, 68, 175, 191, 3, 3, 0, null, null, null),
  ('franck-nekpadro', 'Franck', 'Nekpadro', 'THE LION', 'CI', 'Heavyweight', 'Striking', '1992-03-13'::date, 100, 187, 195, 0, 1, 0, null, null, null),
  ('bouacar-sylla', 'Bouacar', 'Sylla', 'SYLLA', 'ML', 'Featherweight', 'Striking', '2000-04-13'::date, 64, 175, 185, 0, 2, 0, null, null, null),
  ('drissa-soro', 'Drissa', 'Soro', 'DRIJOHN', 'CI', 'Featherweight', 'Striking', '2005-12-03'::date, 59, 153, 160, 2, 0, 0, null, null, null),
  ('zakaria-kouakou', 'Zakaria', 'Kouakou', 'LE TRANSCENDENTAL', 'CI', 'Featherweight', 'Striking', '1999-01-26'::date, 63, 172, 187, 5, 2, 0, null, null, null),
  ('amara-bakayoko', 'Amara', 'Bakayoko', 'WARABA', 'CI', 'Welterweight', 'Striking', '1988-11-27'::date, 75, 172, 175, 0, 2, 0, null, null, null),
  ('hamed-doumbia', 'Hamed', 'Doumbia', 'MAESTRO', 'CI', 'Middleweight', 'Striking', '1993-12-10'::date, 82, 184, 200, 1, 1, 0, null, null, null),
  ('cheick-kabore', 'Cheick', 'Kabore', 'LE DRONE', 'CI', 'Welterweight', 'Striking', '1997-08-08'::date, 77, 180, 175, 1, 2, 0, null, null, null),
  ('abdoulaye-dembele', 'Abdoulaye', 'Dembele', 'BLOCO', 'CI', 'Middleweight', 'Striking', '1994-01-01'::date, 77, 172, 183, 1, 2, 0, null, null, null),
  ('mathieu-aboya', 'Mathieu', 'Aboya', 'KOLA SUCRE', 'CM', 'Welterweight', null, '1992-09-21'::date, 77, 172, 180, 1, 0, 0, null, null, null),
  ('steve-lekeufack', 'Steve', 'Lekeufack', 'DAMON', 'CM', 'Middleweight', null, '1999-08-16'::date, 82, 176, 180, 0, 1, 0, null, null, null),
  ('salim-zigui-dona', 'Salim', 'Zigui Dona', 'KOMANDER SAMON', 'CI', 'Middleweight', 'Striking', '1995-12-22'::date, 84, 178, 188, 2, 0, 0, null, null, null),
  ('kevin-bogah', 'Kevin', 'Bogah', null, 'CI', 'Welterweight', 'Striking', '1996-10-14'::date, 77, 180, 190, 1, 0, 0, null, null, null),
  ('herve-kouame', 'Hervé', 'Kouame', 'MR ATTITUDE', 'CI', 'Featherweight', 'Striking', '2000-06-21'::date, 60, 170, 177, 3, 2, 0, null, null, null),
  ('jhon-kennedy-affognon', 'Jhon Kennedy', 'Affognon', 'JHONOSTAR', 'BJ', 'Middleweight', 'Striking', '1998-11-18'::date, 84, 185, 190, 0, 2, 0, null, null, null),
  ('jean-philippe-djidja', 'Jean Philippe', 'Djidja', 'LEPRIMATE', 'CI', 'Heavyweight', 'Grappling', '1987-12-06'::date, 94, 173, 177, 2, 1, 0, 0, 1, 0),
  ('tijane-diallo', 'Tijane', 'Diallo', null, 'SN', 'Featherweight', 'Striking', null::date, 66, 175, 185, 1, 1, 0, null, null, null),
  ('phils-fahida', 'Phils', 'Fahida', 'TIGER', 'CI', 'Welterweight', 'Striking', '1999-07-28'::date, 71, 182, 193, 1, 2, 0, null, null, null),
  ('adama-diop', 'Adama', 'Diop', 'BLINDE', 'SN', 'Heavyweight', 'Grappling', '1994-12-10'::date, 119, 190, 207, 1, 0, 0, null, null, null),
  ('moussa-sounkara', 'Moussa', 'Sounkara', null, 'ML', 'Middleweight', 'Striking', '1989-12-18'::date, 80, 175, 180, 0, 1, 0, null, null, null),
  ('abdoulaye-diassana', 'Abdoulaye', 'Diassana', null, 'ML', 'Welterweight', 'Striking', '2000-09-03'::date, 73, 170, 180, 0, 1, 0, null, null, null),
  ('durrehl-tchikaya-mouelet', 'Durrehl', 'Tchikaya Mouelet', 'L’AIGLE ROYAL', 'CD', 'Featherweight', 'Grappling', '1991-05-03'::date, 60, 178, 185, 0, 2, 0, null, null, null),
  ('drissa-traore', 'Drissa', 'Traore', null, 'ML', 'Middleweight', null, '1989-05-26'::date, 80, 190, 175, 0, 1, 0, null, null, null),
  ('bryan-rwan', 'Bryan', 'Rwan', 'CHRISTIANO', 'CI', 'Welterweight', 'Striking', '1993-01-30'::date, 70, 177, 188, 1, 2, 0, null, null, null),
  ('ange-ezechiel-gouba', 'Ange Ezechiel', 'Gouba', 'EZEZO', 'CI', 'Heavyweight', 'Grappling', '2002-05-26'::date, 118, 188, 153, 0, 1, 0, null, null, null),
  ('kouakou-akale', 'Kouakou', 'Akale', 'MAÎTRE CHANG LEE', 'CI', 'Welterweight', 'Striking', '1991-11-07'::date, 59, 153, 160, 0, 1, 0, null, null, null),
  ('michael-kouame-ahouzi', 'Michael Kouame', 'Ahouzi', 'PANTHERA', 'FR', 'Welterweight', 'Striking', '1990-09-21'::date, 77, 191, 201, 1, 0, 0, null, null, null),
  ('amour-mouyabi', 'Amour', 'Mouyabi', 'KRISHNA', 'CG', 'Welterweight', null, '1992-11-05'::date, 75, 185, 200, 1, 0, 0, null, null, null),
  ('kanda-goundouba', 'Kanda', 'Goundouba', 'G-KWSON', 'CI', 'Featherweight', 'Striking', '1996-04-17'::date, 63, 173, 181, 2, 4, 0, null, null, null),
  ('saliou-sonde', 'Saliou', 'Sonde', null, 'BF', 'Featherweight', 'Striking', null::date, 63, 172, 200, 0, 1, 0, null, null, null),
  ('abdramane-maiga', 'Abdramane', 'Maiga', null, 'ML', 'Featherweight', 'Striking', '2001-06-19'::date, 65, 185, 200, 1, 1, 0, null, null, null);

  insert into public.fighters(slug, first_name, last_name, nickname, country_code, date_of_birth,
                              height_cm, weight_kg, reach_cm, weight_category_id, fighting_style, is_active)
  select s.slug, s.first_name, s.last_name, s.nickname, s.country_code, s.dob,
         s.height_cm, s.weight_kg, s.reach_cm, w.id, coalesce(s.style, 'MMA'), true
    from _aml_seed s
    join public.weight_categories w on w.name = s.category
  on conflict (slug) do update set
    nickname = excluded.nickname, country_code = excluded.country_code,
    date_of_birth = coalesce(excluded.date_of_birth, public.fighters.date_of_birth),
    height_cm = excluded.height_cm, weight_kg = excluded.weight_kg, reach_cm = excluded.reach_cm,
    weight_category_id = excluded.weight_category_id,
    fighting_style = excluded.fighting_style, is_active = true, updated_at = now();

  get diagnostics v_people = row_count;

  insert into public.fighter_stats(fighter_id, wins, losses, draws, amateur_wins, amateur_losses, amateur_draws)
  select f.id, coalesce(s.pro_w, 0), coalesce(s.pro_l, 0), coalesce(s.pro_d, 0),
         coalesce(s.am_w, 0), coalesce(s.am_l, 0), coalesce(s.am_d, 0)
    from _aml_seed s join public.fighters f on f.slug = s.slug
  on conflict (fighter_id) do update set
    wins = excluded.wins, losses = excluded.losses, draws = excluded.draws,
    amateur_wins = excluded.amateur_wins, amateur_losses = excluded.amateur_losses,
    amateur_draws = excluded.amateur_draws, updated_at = now();

  -- 4. AML 10 event ---------------------------------------------------------
  select e.id into v_event from public.events e
   where e.slug in ('aml-10', 'aml10') or e.name ilike 'aml%10%' order by e.created_at limit 1;

  if v_event is null then
    insert into public.events(name, slug, description, venue_name, city, country_code, starts_at, status, competition_id)
    values ('AML 10', 'aml-10',
            'African MMA League — AML 10, sous le haut patronage de M. Lacina Ouattara (Lass PR), député-maire de Korhogo. Grand public 1000 F, VIP 5000 F.',
            'Espace Obali', 'Korhogo', 'CI', v_starts, 'published', v_comp)
    returning id into v_event;
  else
    update public.events set
      competition_id = v_comp,
      venue_name = coalesce(venue_name, 'Espace Obali'),
      city = coalesce(city, 'Korhogo'),
      country_code = coalesce(country_code, 'CI'),
      starts_at = coalesce(starts_at, v_starts),
      status = case when status = 'draft' then 'published' else status end
    where id = v_event;
  end if;

  -- 5. The 9 fights of the poster (bout_order 1 = main event) -----------------
  create temp table _aml_card (bout_order int, a_slug text, b_slug text, category text) on commit drop;
  insert into _aml_card values
  (1, 'yacouba-sare', 'mohammed-abidi', 'Welterweight'),
  (2, 'hamza-gourtite', 'salif-diakite', 'Heavyweight'),
  (3, 'abdallah-mohamed', 'pelajah-osoba', 'Lightweight'),
  (4, 'rahima-chikh-amine', 'symphorose-kiala', 'Flyweight (F)'),
  (5, 'soufiane-el-kalbi', 'souleymane-sidibe', 'Featherweight'),
  (6, 'taofeek-rokibu', 'amine-mamdouhi', 'Welterweight'),
  (7, 'joseph-bessala-owono', 'saleh-kapenda-ken', 'Welterweight'),
  (8, 'mary-victory-nde-bih', 'zineb-hassoune', 'Flyweight (F)'),
  (9, 'enoch-sackey', 'romeo-tsla-nga', 'Middleweight');

  -- Existing pair on this card: just realign order and category.
  update public.fights x set bout_order = c.bout_order, weight_category_id = w.id
    from _aml_card c
    join public.fighters fa on fa.slug = c.a_slug
    join public.fighters fb on fb.slug = c.b_slug
    join public.weight_categories w on w.name = c.category
   where x.event_id = v_event
     and ((x.fighter_a_id = fa.id and x.fighter_b_id = fb.id) or (x.fighter_a_id = fb.id and x.fighter_b_id = fa.id));

  insert into public.fights(event_id, fighter_a_id, fighter_b_id, weight_category_id, bout_order,
                            scheduled_rounds, title_bout, status)
  select v_event, fa.id, fb.id, w.id, c.bout_order, 3, false, 'scheduled'
    from _aml_card c
    join public.fighters fa on fa.slug = c.a_slug
    join public.fighters fb on fb.slug = c.b_slug
    join public.weight_categories w on w.name = c.category
   where not exists (
     select 1 from public.fights x
      where x.event_id = v_event
        and ((x.fighter_a_id = fa.id and x.fighter_b_id = fb.id) or (x.fighter_a_id = fb.id and x.fighter_b_id = fa.id)));
  get diagnostics v_added = row_count;

  select count(*) into v_other from public.fights x
   where x.event_id = v_event
     and not exists (
       select 1 from _aml_card c
         join public.fighters fa on fa.slug = c.a_slug
         join public.fighters fb on fb.slug = c.b_slug
        where (x.fighter_a_id = fa.id and x.fighter_b_id = fb.id) or (x.fighter_a_id = fb.id and x.fighter_b_id = fa.id));

  -- 6. Prediction questions (only if the auto-prediction function is installed).
  if to_regprocedure('public.aml_ensure_fight_prediction(uuid)') is not null then
    perform public.aml_ensure_fight_prediction(f.id)
       from public.fights f where f.event_id = v_event and f.status = 'scheduled';
  end if;

  raise notice 'AML 10 (%): % combattants traités, % combats ajoutés.', v_event, v_people, v_added;
  if v_other > 0 then
    raise notice 'Attention : % autre(s) combat(s) déjà présent(s) sur AML 10 (tests ?) ne figurent pas sur l''affiche.', v_other;
  end if;
end
$seed$;

-- OPTIONAL: remove the generic French categories seeded earlier, if nothing uses them.
-- delete from public.weight_categories w
--  where w.name like 'Poids %'
--    and not exists (select 1 from public.fighters f where f.weight_category_id = w.id)
--    and not exists (select 1 from public.fights x where x.weight_category_id = w.id);

notify pgrst, 'reload schema';
commit;
