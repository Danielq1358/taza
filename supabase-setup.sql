create table if not exists public.weekly_availability (
  weekday smallint primary key check (weekday between 0 and 6),
  is_open boolean not null default false
);

insert into public.weekly_availability (weekday, is_open)
select day_number, false
from generate_series(0, 6) as day_number
on conflict (weekday) do nothing;

alter table public.weekly_availability enable row level security;

drop policy if exists "Anyone can view weekly availability" on public.weekly_availability;
create policy "Anyone can view weekly availability"
  on public.weekly_availability for select
  to anon, authenticated
  using (true);

drop policy if exists "Only the shop owner can update availability" on public.weekly_availability;
create policy "Only the shop owner can update availability"
  on public.weekly_availability for update
  to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = lower('Mauriciodanielriveracruz@gmail.com'))
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = lower('Mauriciodanielriveracruz@gmail.com'));

grant select on public.weekly_availability to anon, authenticated;
grant update on public.weekly_availability to authenticated;

create table if not exists public.shop_notice (
  id smallint primary key check (id = 1),
  notice_type text not null default 'none'
    check (notice_type in ('none', 'drizzle', 'rain', 'wind', 'storm', 'other')),
  message text not null default '',
  updated_at timestamptz not null default now()
);

insert into public.shop_notice (id, notice_type, message)
values (1, 'none', '')
on conflict (id) do nothing;

alter table public.shop_notice enable row level security;

drop policy if exists "Anyone can view shop notice" on public.shop_notice;
create policy "Anyone can view shop notice"
  on public.shop_notice for select
  to anon, authenticated
  using (true);

drop policy if exists "Only the shop owner can update shop notice" on public.shop_notice;
create policy "Only the shop owner can update shop notice"
  on public.shop_notice for update
  to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = lower('Mauriciodanielriveracruz@gmail.com'))
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = lower('Mauriciodanielriveracruz@gmail.com'));

grant select on public.shop_notice to anon, authenticated;
grant update on public.shop_notice to authenticated;

create table if not exists public.shop_orders (
  id uuid primary key,
  created_at timestamptz not null default now(),
  customer_email text not null,
  customer_name text not null,
  customer_phone text not null default '',
  quantity integer not null check (quantity > 0),
  fulfillment_method text not null check (fulfillment_method in ('pickup', 'delivery')),
  delivery_address text not null default '',
  delivery_distance_meters bigint check (delivery_distance_meters is null or delivery_distance_meters > 0),
  product_price text not null,
  delivery_price text not null,
  total_price text not null,
  message text not null default '',
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected'))
);

create index if not exists shop_orders_customer_email_created_at_idx
  on public.shop_orders (lower(customer_email), created_at desc);

alter table public.shop_orders enable row level security;

drop policy if exists "Customers and shop owner can view authorized orders" on public.shop_orders;
create policy "Customers and shop owner can view authorized orders"
  on public.shop_orders for select
  to authenticated
  using (
    lower(customer_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    or lower(coalesce(auth.jwt() ->> 'email', '')) = lower('Mauriciodanielriveracruz@gmail.com')
  );

drop policy if exists "Public can submit pending orders" on public.shop_orders;
create policy "Public can submit pending orders"
  on public.shop_orders for insert
  to anon, authenticated
  with check (
    status = 'pending'
    and length(trim(customer_email)) between 5 and 120
    and length(trim(customer_name)) between 1 and 80
    and quantity between 1 and 1000
  );

drop policy if exists "Only the shop owner can update orders" on public.shop_orders;
create policy "Only the shop owner can update orders"
  on public.shop_orders for update
  to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = lower('Mauriciodanielriveracruz@gmail.com'))
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = lower('Mauriciodanielriveracruz@gmail.com'));

grant select on public.shop_orders to authenticated;
grant insert (
  id,
  customer_email,
  customer_name,
  customer_phone,
  quantity,
  fulfillment_method,
  delivery_address,
  delivery_distance_meters,
  product_price,
  delivery_price,
  total_price,
  message
) on public.shop_orders to anon, authenticated;
grant update (status) on public.shop_orders to authenticated;
