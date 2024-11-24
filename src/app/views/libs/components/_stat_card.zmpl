@args label: []const u8, value: []const u8, icon: []const u8

<div class="stat-card">
    <div class="stat-info">
        <span class="stat-label">{{label}}</span>
        <span class="stat-value">{{value}}</span>
    </div>
    <img src="/icons/{{icon}}.svg" />
</div>

<style>
    .stat-card {
        display: flex;
        justify-content: space-between;
        align-items: center;
        width: 100%;
        padding: 16px;
        background: var(--color-surface);
        border-radius: 12px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.05);
        transition: transform 0.2s ease;
    }

    .stat-card:hover {
        transform: translateY(-2px);
    }

    .stat-info {
        display: flex;
        flex-direction: column;
        gap: 4px;
    }

    .stat-label {
        white-space: nowrap;
        font-size: 14px;
        color: var(--color-text-primary);
        opacity: 0.7;
    }

    .stat-value {
        white-space: nowrap;
        font-size: 24px;
        font-weight: 600;
        color: var(--color-text-primary);
        font-family: 'Georgia', serif;
    }

    .stat-icon {
        width: 24px;
        height: 24px;
        color: #27ae60;
        opacity: 0.8;
    }

</style>
