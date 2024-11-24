<div class="main-content">
    <div class="content-header">
        <div class="header-main">
            <div class="header-topbar">
                <h1>Products</h1>
                @partial libs/components/btn_add("Product")
            </div>
            <div class="header-stats">
                <div class="stat-card">
                    <div class="stat-info">
                        <span class="stat-label">Total Products</span>
                        <span class="stat-value">2,459</span>
                    </div>
                    @partial libs/icons/stat_products_total
                </div>

                <div class="stat-card">
                    <div class="stat-info">
                        <span class="stat-label">In Stock</span>
                        <span class="stat-value">1,857</span>
                    </div>
                    @partial libs/icons/stat_products_instock
                </div>

                <div class="stat-card">
                    <div class="stat-info">
                        <span class="stat-label">Low Stock</span>
                        <span class="stat-value">324</span>
                    </div>
                    @partial libs/icons/stat_products_lowstock
                </div>

                <div class="stat-card">
                    <div class="stat-info">
                        <span class="stat-label">Out of Stock</span>
                        <span class="stat-value">278</span>
                    </div>
                    @partial libs/icons/stat_products_outofstock
                </div>
            </div>
        </div>

    </div>

    <div class="controls-section">
        <!-- Search and Filters -->
        @partial libs/components/search_box
        @partial libs/components/products_filter_controls
    </div>

    @partial admin/products/table/content

</div>


<!-- include shared styles first -->
@partial libs/styles/content_header
@partial libs/styles/controls_section
@partial libs/styles/table_section

<style>
    .stat-icon.warning {
        color: #f1c40f;
    }

    .stat-icon.danger {
        color: #e74c3c;
    }

    .product-cell {
        display: flex;
        align-items: center;
        gap: 12px;
    }

    .product-image {
        width: 40px;
        height: 40px;
        border-radius: 8px;
        object-fit: cover;
    }

    .product-info {
        display: flex;
        flex-direction: column;
    }

    .product-name {
        color: var(--color-text-primary);
        font-weight: 500;
    }

    .product-sku {
        font-size: 13px;
        color: var(--color-text-primary);
        opacity: 0.6;
    }

    .status-badge {
        padding: 4px 12px;
        border-radius: 20px;
        font-size: 13px;
        font-weight: 500;
    }

    .status-badge.in-stock {
        background: rgba(39, 174, 96, 0.1);
        color: #27ae60;
    }

    .status-badge.low-stock {
        background: rgba(241, 196, 15, 0.1);
        color: #f1c40f;
    }

    .status-badge.out-of-stock {
        background: rgba(231, 76, 60, 0.1);
        color: #e74c3c;
    }

    .actions-cell {
        display: flex;
        gap: 8px;
    }

    .action-btn {
        padding: 6px;
        border: none;
        border-radius: 6px;
        background: none;
        cursor: pointer;
        transition: all 0.2s ease;
    }

    .action-btn svg {
        width: 18px;
        height: 18px;
    }

    .action-btn.edit {
        color: #3498db;
    }

    .action-btn.delete {
        color: #e74c3c;
    }

    .action-btn:hover {
        background: rgba(0,0,0,0.05);
    }

    @media (max-width: 768px) {

        .product-cell {
            flex-direction: column;
            align-items: flex-start;
        }

        .actions-cell {
            flex-direction: column;
        }
    }

</style>
