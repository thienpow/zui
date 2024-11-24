<style>
    .content-header {
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
        margin-bottom: 32px;
        gap: 20px;
    }

    .header-main {
        flex: 1;
    }

    .header-topbar {
        display: flex;
        align-items: center;
        justify-content: space-between;
    }

    .header-main h1 {
        margin-bottom: 20px;
        color: var(--color-text-primary);
    }

    .header-stats {
        display: grid;
        grid-template-columns: repeat(4, 1fr); /* 4 columns by default */
        gap: 16px;
    }

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


    @media (max-width: 1024px) {
        .header-stats {
            grid-template-columns: repeat(2, 1fr); /* 2 columns on medium screens */
        }

    }

    @media (max-width: 480px) {
        .header-stats {
            gap: 8px;  /* Reduce gap on smaller screens */
        }

        .stat-value {
            font-size: 20px;
        }

        .stat-label {
            font-size: 13px;
        }

        .stat-icon {
            width: 20px;
            height: 20px;
        }

        .stat-card {
            padding: 12px;
        }
    }
</style>
