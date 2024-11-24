<div class="main-content">
    <div class="content-header">
        <div class="header-main">
            <h1>Orders</h1>
            <div class="header-stats">
                <div class="stat-card">
                    <div class="stat-info">
                        <span class="stat-label">Total Orders</span>
                        <span class="stat-value">1,234</span>
                    </div>
                    @partial libs/icons/stat_orders_total
                </div>

                <div class="stat-card">
                    <div class="stat-info">
                        <span class="stat-label">Pending</span>
                        <span class="stat-value">45</span>
                    </div>
                    @partial libs/icons/stat_orders_pending
                </div>

                <div class="stat-card">
                    <div class="stat-info">
                        <span class="stat-label">Processing</span>
                        <span class="stat-value">89</span>
                    </div>
                    @partial libs/icons/stat_orders_processing
                </div>

                <div class="stat-card">
                    <div class="stat-info">
                        <span class="stat-label">Completed</span>
                        <span class="stat-value">1,100</span>
                    </div>
                    @partial libs/icons/stat_orders_success
                </div>
            </div>
        </div>
    </div>

    <div class="controls-section">
        @partial libs/components/search_box
        @partial libs/components/orders_filter_controls
    </div>

    @partial admin/orders/table/content
</div>


<!-- include shared styles first -->
@partial libs/styles/content_header
@partial libs/styles/controls_section
@partial libs/styles/table_section

<style>
    .customer-cell {
        display: flex;
        align-items: center;
        gap: 12px;
    }

    .customer-info {
        display: flex;
        flex-direction: column;
    }

    .customer-name {
        font-weight: 500;
        color: var(--color-text-primary);
    }

    .customer-email {
        font-size: 13px;
        color: var(--color-text-primary);
        opacity: 0.6;
    }

    .date-info {
        display: flex;
        flex-direction: column;
    }

    .date {
        color: var(--color-text-primary);
    }

    .time {
        font-size: 13px;
        color: var(--color-text-primary);
        opacity: 0.6;
    }

    .amount {
        font-weight: 600;
        color: var(--color-text-primary);
        font-family: 'Georgia', serif;
    }

    .order-id {
        font-family: monospace;
        font-size: 14px;
        color: var(--color-text-primary);
        opacity: 0.8;
    }

    .status-badge {
        padding: 6px 12px;
        border-radius: 20px;
        font-size: 13px;
        font-weight: 500;
    }

    .status-badge.pending {
        background: rgba(241, 196, 15, 0.1);
        color: #f1c40f;
    }

    .status-badge.processing {
        background: rgba(52, 152, 219, 0.1);
        color: #3498db;
    }

    .status-badge.completed {
        background: rgba(39, 174, 96, 0.1);
        color: #27ae60;
    }

    .status-badge.cancelled {
        background: rgba(231, 76, 60, 0.1);
        color: #e74c3c;
    }

    /* Icon colors */
    .stat-icon.warning {
        color: #f1c40f;
    }

    .stat-icon.processing {
        color: #3498db;
    }

    .stat-icon.success {
        color: #27ae60;
    }

    /* Action buttons */
    .action-btn.view {
        color: #3498db;
    }

    @media (max-width: 768px) {
        .customer-cell {
            flex-direction: row; /* Keep horizontal layout */
            align-items: center;
        }

        .date-info {
            flex-direction: row;
            gap: 8px;
            align-items: center;
        }

        .time::before {
            content: "•";
            margin-right: 8px;
        }
    }

</style>
