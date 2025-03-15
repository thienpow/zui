<style>
    :root {
        /* Colors */
        --color-primary: #2c3e50;
        --color-secondary: #34495e;
        --color-accent: #ffc107;
        --color-inactive: #ccc;
        --color-bg: #f5f5f0;
        --color-surface: #f5f5f5;
        --color-text-primary: #2c3e50;
        --color-text-secondary: #6c757d;

        /* Spacing */
        --spacing-small: 0.5rem;
        --spacing-medium: 1rem;
        --spacing-large: 2rem;

        /* Typography */
        --font-family-base: 'Roboto', sans-serif;
        --font-size-base: 1rem;
        --font-size-large: 1.25rem;
        --font-size-small: 0.875rem;

        /* Borders */
        --border-radius: 0.5rem;
        --border-width: 1px;

        /* Shadows */
        --box-shadow: 0px 4px 6px rgba(0, 0, 0, 0.1);

        /* Transitions */
        --transition-duration: 0.3s;
        --transition-timing-function: ease-in-out;
    }


    * {
        margin: 0;
        padding: 0;
        box-sizing: border-box;
    }

    body {
        background-color: var(--color-bg);
        color: var(--color-text-primary);
        font-family: var(--font-family-base);
    }

    section {
        background: inherit;
        border-radius: 12px;
        box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
        overflow: hidden;
    }

    input {
        border: 1px solid rgba(0,0,0,0.1);
        border-radius: var(--border-radius);
        background: inherit;
        transition: all 0.2s ease;
        color: var(--color-text-primary);
    }

    input:focus {
        outline: none;
        border-color: var(--color-accent);
        box-shadow: 0 0 1px var(--color-accent);
    }

    button {
        background: var(--color-primary);
        border: 1px solid rgba(0,0,0,0.1);
        color: white;
        border-radius: var(--border-radius);
        cursor: pointer;
        transition: all 0.2s ease;
    }

    button:hover {
        opacity: 0.9;
        color: var(--color-text-primary);
        background: var(--color-accent);
        transform: translateY(-1px);
    }

    a, a:hover, a:active, a:visited {
        text-decoration: none;
    }

    select {
        border: 1px solid rgba(0, 0, 0, 0.1);
        padding: 10px 20px;
        border-radius: var(--border-radius);
        background: var(--color-surface);
        color: var(--color-text-primary);
        cursor: pointer;
    }

    .btn-icon {
        width: 20px;
        height: 20px;
    }

</style>
