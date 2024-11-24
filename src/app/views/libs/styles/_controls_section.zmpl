<style>
    .controls-section {
        display: flex;
        gap: 20px;
        margin-bottom: 24px;
        flex-wrap: wrap;
    }

    .filter-controls {
        display: flex;
        gap: 12px;
        flex-wrap: wrap;
    }

    @media (max-width: 768px) {
        .controls-section {
            flex-direction: column;
        }

        .filter-controls {
            width: 100%;
        }

        .filter-select {
            flex: 1;
        }
    }
</style>
