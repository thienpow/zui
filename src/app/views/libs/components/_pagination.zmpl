<div class="pagination">
    <button class="page-btn previous" disabled>Previous</button>
    <div class="page-numbers">
        <button class="page-btn active">1</button>
        <button class="page-btn">2</button>
        <button class="page-btn">3</button>
        <span>...</span>
        <button class="page-btn">10</button>
    </div>
    <button class="page-btn next">Next</button>
</div>
<style>
    .pagination {
        display: flex;
        justify-content: center;
        align-items: center;
        margin: 24px;
    }

    .page-btn.previous {
        margin-right: 8px;
    }
    .page-btn.next {
        margin-left: 8px;
    }
    .page-numbers {
        display: flex;
        gap: 8px;
        align-items: center;
    }

    .page-btn {
        padding: 8px 16px;
        border-radius: var(--border-radius);
        background: var(--color-surface);
        color: var(--color-text-primary);
        cursor: pointer;
        transition: all 0.2s ease;
    }

    .page-btn.active {
        background: var(--color-primary);
        color: white;
        border-color: var(--color-primary);
        pointer-events: none;
        cursor: default;
    }

    .page-btn:disabled {
        opacity: 0.5;
        color: gray;
        background: var(--color-primary);
        cursor: default;
        pointer-events: none;
    }

    @media (max-width: 480px) {

        .page-btn {
            padding: 6px 10px;
            position: relative;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            background: none;
            border: none;
        }
        /* Hide text and replace for Previous button */
        .page-btn.previous {
            color: transparent;
            font-size: 0;
        }
        .page-btn.next {
            color: transparent;
            font-size: 0;
        }

        /* Replace text for the Previous button */
        .page-btn.previous::before {
            content: '';
            display: inline-block;
            width: 24px;
            height: 24px;
            background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M15 18l-6-6 6-6' /%3E%3C/svg%3E");
            background-repeat: no-repeat;
            background-size: contain;
        }

        /* Replace text for the Next button */
        .page-btn.next::before {
            content: '';
            display: inline-block;
            width: 24px;
            height: 24px;
            background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M9 18l6-6-6-6' /%3E%3C/svg%3E");
            background-repeat: no-repeat;
            background-size: contain;
        }
    }
</style>
