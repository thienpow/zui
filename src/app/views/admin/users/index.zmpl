<div class="main-content">
    <div class="content-header">
        <div class="header-main">
            <div class="header-topbar">
                <h1>Users</h1>
                @partial libs/components/btn_add("User")
            </div>
            <div class="header-stats">
                <div class="stat-card">
                    <div class="stat-info">
                        <span class="stat-label">Total Users</span>
                        <span class="stat-value">15,847</span>
                    </div>
                    @partial libs/icons/stat_users_total
                </div>

                <div class="stat-card">
                    <div class="stat-info">
                        <span class="stat-label">Active</span>
                        <span class="stat-value">12,453</span>
                    </div>
                    @partial libs/icons/stat_users_active
                </div>

                <div class="stat-card">
                    <div class="stat-info">
                        <span class="stat-label">Inactive</span>
                        <span class="stat-value">2,847</span>
                    </div>
                    @partial libs/icons/stat_users_inactive
                </div>

                <div class="stat-card">
                    <div class="stat-info">
                        <span class="stat-label">Banned</span>
                        <span class="stat-value">547</span>
                    </div>
                    @partial libs/icons/stat_users_banned
                </div>
            </div>
        </div>

    </div>

    <div class="controls-section">
        @partial libs/components/search_box
        @partial libs/components/users_filter_controls
    </div>

    @partial admin/users/table/content
</div>

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

    .user-cell {
        display: flex;
        align-items: center;
        gap: 12px;
    }

    .user-avatar {
        width: 40px;
        height: 40px;
        border-radius: 50%;
        object-fit: cover;
    }

    .user-info {
        display: flex;
        flex-direction: column;
    }

    .user-name {
        color: var(--color-text-primary);
        font-weight: 500;
    }

    .user-id {
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

    .status-badge.active {
        background: rgba(39, 174, 96, 0.1);
        color: #27ae60;
    }

    .status-badge.inactive {
        background: rgba(241, 196, 15, 0.1);
        color: #f1c40f;
    }

    .status-badge.banned {
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

        .user-cell {
            flex-direction: column;
            align-items: flex-start;
        }

        .actions-cell {
            flex-direction: column;
        }
    }
</style>
