<div class="topbar">
    @partial libs/components/ask_ai
    @partial libs/components/user_info
</div>

<style>
    .topbar {
        position: fixed;
        left: 250px;
        top: 0;
        width: calc(100% - 250px);
        height: 60px;
        background: inherit;
        padding: 0 20px;
        display: flex;
        align-items: center;
        justify-content: space-between;
        z-index: 80;
    }

    /* Media query for small screens */
    @media (max-width: 768px) {
        .topbar {
            left: 0;
            width: 100%;
            padding-left: 60px; /* Make room for sidebar toggle */
            justify-content: flex-end; /* Align any visible content to the right */
        }

    }

</style>
