-- Fletes detallados privados asociados a cada producto.
alter table public.inventory_items
  add column if not exists freight_legs jsonb not null default '[]'::jsonb;
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.inventory_items'::regclass
      and conname = 'inventory_freight_legs_check'
  ) then
    alter table public.inventory_items
      add constraint inventory_freight_legs_check
      check (jsonb_typeof(freight_legs) = 'array' and jsonb_array_length(freight_legs) <= 20);
  end if;
end $$;
comment on column public.inventory_items.freight_legs is 'Costos privados de hasta 20 tramos de envío por producto: origen, destino, agencia, costo total y unidades a distribuir. freight_cost conserva el total unitario calculado.';