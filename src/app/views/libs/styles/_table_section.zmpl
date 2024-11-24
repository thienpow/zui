<style>
    .table-section {
        border-radius: 12px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.05);
        overflow-x: auto;
    }

    .table {
        width: 100%;
        border-collapse: collapse;
    }

    .table th {
        padding: 16px;
        text-align: left;
        border-bottom: 1px solid rgba(169, 169, 169, 0.1);
        color: var(--color-text-primary);
        font-weight: 600;
    }

    .table tr {
        border-top: 1px solid rgba(169, 169, 169, 0.05);
    }

    .table td {
        padding: 16px;
    }


    @media (max-width: 1100px) {
        .table {
            display: block;
            overflow-x: auto;
            white-space: nowrap;
        }
    }
</style>
