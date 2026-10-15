# Architecture

Schema after migrations 0001–0005 in [`supabase/migrations/`](../supabase/migrations), plus
[`supabase/functions/staff-admin`](../supabase/functions/staff-admin).

## System

```mermaid
flowchart TB
  subgraph App["Flutter app"]
    S["presentation/ (screens, app_shell tabsFor(role))"]
    C["Riverpod: providers.dart, SessionController, CheckoutController"]
    Repo["data/repositories/ (Product, Stock, Transaction, Profile, Staff, Auth)"]
    S --> C --> Repo
  end
  subgraph Supabase
    Auth["Auth (email / username@staff.pos.invalid)"]
    PG[("Postgres: RLS + SECURITY DEFINER RPCs")]
    Stor["Storage: product-images"]
    Fn["Edge Function: staff-admin"]
  end
  Repo -->|sign in, session| Auth
  Repo -->|SELECT| PG
  Repo -->|RPC writes| PG
  Repo -->|images| Stor
  Repo -->|create / set_password / set_active| Fn
  Fn -->|service role, server env only| Auth
  Fn -->|profiles| PG
```

All Supabase calls live in `lib/data/repositories/`. The client key must be publishable;
`core/supabase_key_guard.dart` rejects `sb_secret_` keys and `service_role` JWTs at startup.

## Data model

```mermaid
erDiagram
  AUTH_USERS ||--|| profiles : "has"
  AUTH_USERS ||--o{ transactions : "cashier_id"
  categories ||--o{ products : "category_id"
  products ||--o| product_costs : "owner-only cost"
  products ||--o{ stocks : "batches"
  products ||--o{ transaction_items : "sold as"
  products ||--o{ stock_movements : "ledger"
  transactions ||--|{ transaction_items : "contains"
  transactions ||--o{ stock_movements : "ref_transaction_id"

  profiles {
    uuid id PK
    app_role role "owner | cashier | warehouse"
    boolean is_active
  }
  products {
    text id PK "product code / barcode"
    text brand_name
    int category_id FK
    numeric min_stock
    bigint price "Rupiah"
    boolean is_deleted "soft delete"
  }
  product_costs {
    text product_id PK
    bigint capital_price
  }
  stocks {
    serial id PK
    text product_id FK
    text floor_name
    date expiry_date "null = no expiry"
    numeric quantity "check >= 0"
  }
  transactions {
    serial id PK "receipt number"
    bigint total_amount
    bigint paid_amount
    text payment_method "cash | qris | transfer"
    uuid idempotency_key UK
    uuid cashier_id FK
  }
  transaction_items {
    serial id PK
    int transaction_id FK
    text product_id FK
    text product_name "snapshot"
    numeric quantity
    bigint price_at_purchase "snapshot"
  }
  stock_movements {
    bigint id PK
    text product_id FK
    text floor_name
    date expiry_date
    numeric delta
    text kind "sale | restock | opname | transfer_in | transfer_out"
    int ref_transaction_id FK
  }
```

Constraints worth knowing: `stocks` is unique on `(product_id, floor_name, coalesce(expiry_date, 'infinity'))`,
so one row is one batch. `authenticated` has no `INSERT/UPDATE/DELETE` on `stocks`, `transactions`,
`transaction_items` or `stock_movements`, and no `DELETE` on `products`.

## Checkout sequence

```mermaid
sequenceDiagram
  actor K as Cashier
  participant CC as CheckoutController
  participant TR as TransactionRepository
  participant DB as checkout() RPC
  K->>CC: Pay (cash / qris / transfer)
  Note over CC: idempotency key kept on retry,<br/>new key when cart changes or after success
  CC->>TR: checkout(key, items, paid, method)
  TR->>DB: rpc('checkout', p_key, p_items, p_paid, p_method)
  DB->>DB: role is owner or cashier, method valid
  alt key already used by this cashier
    DB-->>TR: existing receipt JSON
  else new key
    DB->>DB: total from products.price, paid >= total<br/>(qris/transfer: paid = total)
    DB->>DB: INSERT transactions (unique idempotency_key)
    loop each product, batches by expiry, FOR UPDATE, skip expired
      DB->>DB: UPDATE stocks, INSERT stock_movements (sale)
    end
    DB->>DB: INSERT transaction_items (name and price snapshot)
    Note over DB: insufficient stock raises, whole transaction rolls back
    DB-->>TR: receipt JSON (id, totals, method, items)
  end
  CC-->>K: receipt screen (TransactionModel), 80 mm PDF
```

## Role matrix

`lib/core/permissions.dart` (`can(role, Permission)`) mirrors this in the UI but only hides menus.
| Resource | Owner | Cashier | Warehouse | Enforced by |
|---|---|---|---|---|
| `profiles` | read all, update | read self | read self | RLS; trigger blocks changing own role/status |
| `categories` | read, write, delete | read | read, insert, update | RLS |
| `products` | read, insert, update | read | read, insert, update | RLS; trigger: price and `is_deleted` owner-only |
| `product_costs` | all | — | — | RLS |
| `stocks` | read | read | read | RLS; writes via RPC |
| `restock`, `stock_count`, `transfer_stock` | ✅ | — | ✅ | role check inside RPC |
| `create_product_with_stock` | ✅ | — | ✅ (price 0) | role check inside RPC |
| `checkout` | ✅ | ✅ | — | role check inside RPC |
| `transactions`, `transaction_items` | read all | read own | — | RLS |
| `stock_movements` | read | — | read | RLS; writes via RPC |
| Storage `product-images` | read, upload, delete | read | read, upload | storage policies (0003) |
| `staff-admin` | ✅ | — | — | function checks caller is an active owner |
