-- AML V9.3 — publication publique des médias
-- Ne crée pas de nouvelle architecture média : expose uniquement les contenus
-- déjà gérés par les tables existantes.

DO $$
BEGIN
  IF to_regclass('public.videos') IS NOT NULL THEN
    ALTER TABLE public.videos ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS aml_videos_public_read ON public.videos;
    CREATE POLICY aml_videos_public_read
      ON public.videos
      FOR SELECT
      TO anon, authenticated
      USING (status = 'published');
  END IF;

  IF to_regclass('public.video_categories') IS NOT NULL THEN
    ALTER TABLE public.video_categories ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS aml_video_categories_public_read ON public.video_categories;
    CREATE POLICY aml_video_categories_public_read
      ON public.video_categories
      FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;

  IF to_regclass('public.aml_content_items') IS NOT NULL THEN
    ALTER TABLE public.aml_content_items ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS aml_content_items_public_read ON public.aml_content_items;
    CREATE POLICY aml_content_items_public_read
      ON public.aml_content_items
      FOR SELECT
      TO anon, authenticated
      USING (status = 'published');
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
