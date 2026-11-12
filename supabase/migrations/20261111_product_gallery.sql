-- NINA: up to five publicly displayable photos per product. Existing cover retained.
alter table public.products
  add column if not exists gallery_images jsonb not null default '[]'::jsonb;
do $$
begin
  if not exists (select 1 from pg_constraint where conname='products_gallery_images_check' and conrelid='public.products'::regclass) then
    alter table public.products add constraint products_gallery_images_check check (
      jsonb_typeof(gallery_images) = 'array' and jsonb_array_length(gallery_images) <= 5
    );
  end if;
end $$;
comment on column public.products.gallery_images is 'Ordered public catalog photos, up to 5 {url,path} entries. First item is cover; image_url remains compatible.';