-- NINA: private inventory and acquisition costs. Public catalog tables remain unchanged.
create table if not exists public.inventory_items (
  product_id uuid primary key references public.products(id) on delete cascade,
  purchase_cost numeric(12,2) not null default 0 check (purchase_cost >= 0),
  freight_cost numeric(12,2) not null default 0 check (freight_cost >= 0),
  packaging_cost numeric(12,2) not null default 0 check (packaging_cost >= 0),
  stock_qty integer not null default 0 check (stock_qty >= 0),
  min_stock integer not null default 2 check (min_stock >= 0),
  updated_at timestamptz not null default now()
);
create table if not exists public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  quantity_change integer not null check (quantity_change <> 0),
  resulting_qty integer not null check (resulting_qty >= 0),
  reason text not null check (char_length(trim(reason)) between 3 and 240),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);
create index if not exists stock_movements_product_created_idx on public.stock_movements(product_id, created_at desc);
create index if not exists stock_movements_created_at_idx on public.stock_movements(created_at desc);
alter table public.inventory_items enable row level security;
alter table public.stock_movements enable row level security;
revoke all on public.inventory_items from anon, authenticated;
revoke all on public.stock_movements from anon, authenticated;
grant select, insert, update on public.inventory_items to authenticated;
grant select, insert on public.stock_movements to authenticated;
create policy "Only NINA admins read inventory" on public.inventory_items for select to authenticated
using (exists (select 1 from public.admins a where a.user_id = (select auth.uid())));
create policy "Only NINA admins create inventory" on public.inventory_items for insert to authenticated
with check (exists (select 1 from public.admins a where a.user_id = (select auth.uid())));
create policy "Only NINA admins update inventory" on public.inventory_items for update to authenticated
using (exists (select 1 from public.admins a where a.user_id = (select auth.uid())))
with check (exists (select 1 from public.admins a where a.user_id = (select auth.uid())));
create policy "Only NINA admins read stock movements" on public.stock_movements for select to authenticated
using (exists (select 1 from public.admins a where a.user_id = (select auth.uid())));
create policy "Only NINA admins record stock movements" on public.stock_movements for insert to authenticated
with check (created_by = (select auth.uid()) and exists (select 1 from public.admins a where a.user_id = (select auth.uid())));
create or replace function public.adjust_nina_stock(p_product_id uuid, p_change integer, p_reason text)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_stock integer;
begin
  if p_change is null or p_change = 0 or p_reason is null or char_length(trim(p_reason)) < 3 or char_length(trim(p_reason)) > 240 then
    raise exception 'Cantidad y motivo válidos son obligatorios';
  end if;
  update public.inventory_items
  set stock_qty = stock_qty + p_change, updated_at = now()
  where product_id = p_product_id and stock_qty + p_change >= 0
  returning stock_qty into v_stock;
  if not found then
    raise exception 'Producto sin inventario o stock insuficiente';
  end if;
  insert into public.stock_movements(product_id, quantity_change, resulting_qty, reason, created_by)
  values (p_product_id, p_change, v_stock, p_reason, (select auth.uid()));
  return v_stock;
end;
$$;
revoke all on function public.adjust_nina_stock(uuid, integer, text) from public, anon;
grant execute on function public.adjust_nina_stock(uuid, integer, text) to authenticated;
comment on table public.inventory_items is 'Private costing and inventory data. Never expose to public catalog.';
