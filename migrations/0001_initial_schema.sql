PRAGMA foreign_keys = ON;

-- =========================================================
-- FOUNDERS VENT
-- Initial Production Database Schema
-- Migration: 0001_initial_schema.sql
-- =========================================================


-- =========================================================
-- USERS
-- Admin এবং Client login account
-- Staff role ভবিষ্যতে ব্যবহার করা যাবে
-- =========================================================

CREATE TABLE users (
    id TEXT PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'client'
        CHECK (role IN ('admin', 'staff', 'client')),
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'inactive', 'suspended')),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);


-- =========================================================
-- CLIENTS
-- Client business/account information
-- =========================================================

CREATE TABLE clients (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    phone TEXT,
    company_name TEXT,
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_clients_user_id ON clients(user_id);


-- =========================================================
-- TEMPLATES
-- প্রতিটি template আলাদা code module হবে
-- database-এ template-এর metadata থাকবে
-- =========================================================

CREATE TABLE templates (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    description TEXT,
    module_key TEXT NOT NULL UNIQUE,
    version INTEGER NOT NULL DEFAULT 1,
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'inactive')),
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_templates_status ON templates(status);
CREATE INDEX idx_templates_sort_order ON templates(sort_order);


-- =========================================================
-- PRODUCTS
-- একটি Landing Page = একটি Product
-- =========================================================

CREATE TABLE products (
    id TEXT PRIMARY KEY,
    client_id TEXT NOT NULL,
    name TEXT NOT NULL,
    sku TEXT,
    description TEXT,
    price REAL,
    compare_at_price REAL,
    currency TEXT NOT NULL DEFAULT 'BDT',
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'inactive')),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (client_id)
        REFERENCES clients(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_products_client_id ON products(client_id);
CREATE INDEX idx_products_status ON products(status);


-- =========================================================
-- LANDING PAGES
-- Permanent page identity
-- URL/slug পরিবর্তন হলেও internal page ID একই থাকবে
-- =========================================================

CREATE TABLE landing_pages (
    id TEXT PRIMARY KEY,
    client_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    template_id TEXT NOT NULL,

    title TEXT NOT NULL,
    slug TEXT NOT NULL,

    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'published', 'unpublished', 'archived')),

    branding_json TEXT NOT NULL DEFAULT '{}',
    content_json TEXT NOT NULL DEFAULT '{}',
    order_form_json TEXT NOT NULL DEFAULT '{}',
    payment_config_json TEXT NOT NULL DEFAULT '{}',

    published_version_id TEXT,

    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    published_at TEXT,

    FOREIGN KEY (client_id)
        REFERENCES clients(id)
        ON DELETE CASCADE,

    FOREIGN KEY (product_id)
        REFERENCES products(id)
        ON DELETE RESTRICT,

    FOREIGN KEY (template_id)
        REFERENCES templates(id)
        ON DELETE RESTRICT
);

CREATE UNIQUE INDEX idx_landing_pages_client_slug
    ON landing_pages(client_id, slug);

CREATE INDEX idx_landing_pages_client_id
    ON landing_pages(client_id);

CREATE INDEX idx_landing_pages_product_id
    ON landing_pages(product_id);

CREATE INDEX idx_landing_pages_template_id
    ON landing_pages(template_id);

CREATE INDEX idx_landing_pages_status
    ON landing_pages(status);


-- =========================================================
-- MEDIA
-- R2-তে থাকা Logo/Product Images-এর metadata
-- =========================================================

CREATE TABLE media (
    id TEXT PRIMARY KEY,
    client_id TEXT NOT NULL,
    landing_page_id TEXT,
    file_type TEXT NOT NULL,
    file_name TEXT NOT NULL,
    r2_key TEXT NOT NULL UNIQUE,
    mime_type TEXT,
    file_size INTEGER,
    alt_text TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (client_id)
        REFERENCES clients(id)
        ON DELETE CASCADE,

    FOREIGN KEY (landing_page_id)
        REFERENCES landing_pages(id)
        ON DELETE SET NULL
);

CREATE INDEX idx_media_client_id ON media(client_id);
CREATE INDEX idx_media_landing_page_id ON media(landing_page_id);


-- =========================================================
-- TRACKING SETTINGS
-- Client-এর tracking configuration
-- =========================================================

CREATE TABLE tracking_settings (
    id TEXT PRIMARY KEY,
    client_id TEXT NOT NULL UNIQUE,

    meta_pixel_id TEXT,
    ga4_measurement_id TEXT,
    google_tag_manager_id TEXT,
    tiktok_pixel_id TEXT,

    enabled INTEGER NOT NULL DEFAULT 1
        CHECK (enabled IN (0, 1)),

    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (client_id)
        REFERENCES clients(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_tracking_client_id
    ON tracking_settings(client_id);


-- =========================================================
-- DOMAINS
-- Client নিজের domain অথবা Founder's Vent subdomain
-- =========================================================

CREATE TABLE domains (
    id TEXT PRIMARY KEY,
    client_id TEXT NOT NULL,

    domain TEXT NOT NULL UNIQUE,

    type TEXT NOT NULL DEFAULT 'custom'
        CHECK (type IN ('custom', 'subdomain')),

    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (
            status IN (
                'pending',
                'configuring',
                'active',
                'failed',
                'disabled'
            )
        ),

    is_primary INTEGER NOT NULL DEFAULT 0
        CHECK (is_primary IN (0, 1)),

    admin_notes TEXT,

    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (client_id)
        REFERENCES clients(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_domains_client_id ON domains(client_id);
CREATE INDEX idx_domains_status ON domains(status);


-- =========================================================
-- ORDERS
-- Customer order
-- =========================================================

CREATE TABLE orders (
    id TEXT PRIMARY KEY,
    order_number TEXT NOT NULL UNIQUE,

    client_id TEXT NOT NULL,
    landing_page_id TEXT NOT NULL,
    product_id TEXT NOT NULL,

    customer_name TEXT NOT NULL,
    customer_phone TEXT NOT NULL,
    customer_address TEXT NOT NULL,

    quantity INTEGER NOT NULL DEFAULT 1
        CHECK (quantity > 0),

    subtotal REAL,
    delivery_charge REAL NOT NULL DEFAULT 0,
    discount REAL NOT NULL DEFAULT 0,
    total REAL,

    payment_method TEXT NOT NULL DEFAULT 'cod',
    payment_status TEXT NOT NULL DEFAULT 'pending'
        CHECK (
            payment_status IN (
                'pending',
                'paid',
                'failed',
                'refunded'
            )
        ),

    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (
            status IN (
                'pending',
                'confirmed',
                'processing',
                'shipped',
                'delivered',
                'cancelled',
                'returned'
            )
        ),

    customer_fields_json TEXT NOT NULL DEFAULT '{}',
    notes TEXT,

    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (client_id)
        REFERENCES clients(id)
        ON DELETE RESTRICT,

    FOREIGN KEY (landing_page_id)
        REFERENCES landing_pages(id)
        ON DELETE RESTRICT,

    FOREIGN KEY (product_id)
        REFERENCES products(id)
        ON DELETE RESTRICT
);

CREATE INDEX idx_orders_client_id ON orders(client_id);
CREATE INDEX idx_orders_landing_page_id ON orders(landing_page_id);
CREATE INDEX idx_orders_product_id ON orders(product_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created_at ON orders(created_at);


-- =========================================================
-- ORDER STATUS HISTORY
-- Order status পরিবর্তনের history
-- =========================================================

CREATE TABLE order_status_history (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL,

    old_status TEXT,
    new_status TEXT NOT NULL,

    changed_by_user_id TEXT,
    note TEXT,

    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (order_id)
        REFERENCES orders(id)
        ON DELETE CASCADE,

    FOREIGN KEY (changed_by_user_id)
        REFERENCES users(id)
        ON DELETE SET NULL
);

CREATE INDEX idx_order_status_history_order_id
    ON order_status_history(order_id);


-- =========================================================
-- EDIT REQUESTS
-- Client → Admin Edit Request
-- =========================================================

CREATE TABLE edit_requests (
    id TEXT PRIMARY KEY,
    request_number TEXT NOT NULL UNIQUE,

    client_id TEXT NOT NULL,
    landing_page_id TEXT NOT NULL,

    subject TEXT,
    message TEXT NOT NULL,

    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (
            status IN (
                'pending',
                'in_progress',
                'completed',
                'rejected'
            )
        ),

    admin_note TEXT,

    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TEXT,

    FOREIGN KEY (client_id)
        REFERENCES clients(id)
        ON DELETE CASCADE,

    FOREIGN KEY (landing_page_id)
        REFERENCES landing_pages(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_edit_requests_client_id
    ON edit_requests(client_id);

CREATE INDEX idx_edit_requests_landing_page_id
    ON edit_requests(landing_page_id);

CREATE INDEX idx_edit_requests_status
    ON edit_requests(status);

CREATE INDEX idx_edit_requests_created_at
    ON edit_requests(created_at);


-- =========================================================
-- PAGE VERSIONS
-- Landing Page-এর পরিবর্তনের history
-- =========================================================

CREATE TABLE page_versions (
    id TEXT PRIMARY KEY,

    landing_page_id TEXT NOT NULL,

    version_number INTEGER NOT NULL,

    template_id TEXT NOT NULL,

    branding_json TEXT NOT NULL DEFAULT '{}',
    content_json TEXT NOT NULL DEFAULT '{}',
    order_form_json TEXT NOT NULL DEFAULT '{}',
    payment_config_json TEXT NOT NULL DEFAULT '{}',

    created_by_user_id TEXT,

    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (landing_page_id)
        REFERENCES landing_pages(id)
        ON DELETE CASCADE,

    FOREIGN KEY (template_id)
        REFERENCES templates(id)
        ON DELETE RESTRICT,

    FOREIGN KEY (created_by_user_id)
        REFERENCES users(id)
        ON DELETE SET NULL
);

CREATE UNIQUE INDEX idx_page_versions_unique
    ON page_versions(landing_page_id, version_number);

CREATE INDEX idx_page_versions_page_id
    ON page_versions(landing_page_id);


-- =========================================================
-- SESSIONS
-- Secure login session-এর জন্য
-- =========================================================

CREATE TABLE sessions (
    id TEXT PRIMARY KEY,

    user_id TEXT NOT NULL,

    expires_at TEXT NOT NULL,

    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_sessions_user_id
    ON sessions(user_id);

CREATE INDEX idx_sessions_expires_at
    ON sessions(expires_at);


-- =========================================================
-- UPDATED_AT TRIGGERS
-- =========================================================

CREATE TRIGGER users_updated_at
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    UPDATE users
    SET updated_at = CURRENT_TIMESTAMP
    WHERE id = OLD.id;
END;


CREATE TRIGGER clients_updated_at
AFTER UPDATE ON clients
FOR EACH ROW
BEGIN
    UPDATE clients
    SET updated_at = CURRENT_TIMESTAMP
    WHERE id = OLD.id;
END;


CREATE TRIGGER templates_updated_at
AFTER UPDATE ON templates
FOR EACH ROW
BEGIN
    UPDATE templates
    SET updated_at = CURRENT_TIMESTAMP
    WHERE id = OLD.id;
END;


CREATE TRIGGER products_updated_at
AFTER UPDATE ON products
FOR EACH ROW
BEGIN
    UPDATE products
    SET updated_at = CURRENT_TIMESTAMP
    WHERE id = OLD.id;
END;


CREATE TRIGGER landing_pages_updated_at
AFTER UPDATE ON landing_pages
FOR EACH ROW
BEGIN
    UPDATE landing_pages
    SET updated_at = CURRENT_TIMESTAMP
    WHERE id = OLD.id;
END;


CREATE TRIGGER tracking_settings_updated_at
AFTER UPDATE ON tracking_settings
FOR EACH ROW
BEGIN
    UPDATE tracking_settings
    SET updated_at = CURRENT_TIMESTAMP
    WHERE id = OLD.id;
END;


CREATE TRIGGER domains_updated_at
AFTER UPDATE ON domains
FOR EACH ROW
BEGIN
    UPDATE domains
    SET updated_at = CURRENT_TIMESTAMP
    WHERE id = OLD.id;
END;


CREATE TRIGGER orders_updated_at
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    UPDATE orders
    SET updated_at = CURRENT_TIMESTAMP
    WHERE id = OLD.id;
END;


CREATE TRIGGER edit_requests_updated_at
AFTER UPDATE ON edit_requests
FOR EACH ROW
BEGIN
    UPDATE edit_requests
    SET updated_at = CURRENT_TIMESTAMP
    WHERE id = OLD.id;
END;
