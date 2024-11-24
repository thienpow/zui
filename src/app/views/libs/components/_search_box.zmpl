<div class="search-box">
    @partial libs/icons/search_magnify
    <input type="text" placeholder="Search orders..." class="search-input">
</div>
<style>
    .search-box {
        position: relative;
        flex: 1;
        min-width: 200px;
    }

    .search-input {
        width: 100%;
        padding: 10px 40px;
        font-size: 15px;
    }

    .search-icon {
        position: absolute;
        left: 12px;
        top: 50%;
        transform: translateY(-50%);
        width: 20px;
        height: 20px;
        color: var(--color-text-primary);
        opacity: 0.5;
    }
</style>
