<style>
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

p {
    line-height: 1.5; /* Improves readability */
}

p a {
    padding: 0.5rem 0.75rem; /* Finger-friendly tap area */
    display: inline-block; /* Ensures padding applies correctly */
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
