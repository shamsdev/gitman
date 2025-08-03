# Gitman

A simple Bash script to expose Git repository operations as a RESTful API. This allows you to remotely monitor and update a Git repository through simple HTTP requests.

## Features

-   **Remote Git Operations:** Access Git functionalities like `log`, `branch`, and `pull` over a network.
-   **Secure:** Protects endpoints with a mandatory API key.
-   **Lightweight:** Written in pure Bash, with `nc` (netcat) as the only dependency for the server.
-   **Easy Configuration:** All settings are managed through a simple `.env` file.

## Prerequisites

Before you begin, ensure you have the following installed:
-   `bash`
-   `git`
-   `nc` (netcat)

## Setup

1.  **Get the script:**
    Clone this repository or download the `gitman.sh` script.

    ```bash
    git clone https://github.com/your-username/gitman.git
    cd gitman
    ```

2.  **Configuration:**
    Create a `.env` file by copying the sample file:

    ```bash
    cp sample.env .env
    ```

    Now, edit the `.env` file with your specific configuration:

    ```ini
    # Path to the local git repository you want to manage
    GIT_REPO_PATH="/path/to/your/repo"

    # The default branch to operate on
    GIT_BRANCH="main"

    # A secret key to authenticate API requests
    API_KEY="your-secret-api-key"

    # The port for the API server to listen on (optional, defaults to 8080)
    PORT=8080
    ```

## Usage

1.  Make the script executable:
    ```bash
    chmod +x gitman.sh
    ```

2.  Run the server:
    ```bash
    ./gitman.sh
    ```

    If everything is configured correctly, you will see:
    ```
    🚀 Gitman is running on http://localhost:8080
    📁 Repository: /path/to/your/repo
    🌿 Branch: main
    Press Ctrl+C to stop.
    ```

## API Endpoints

All requests must include the `X-API-Key` header for authentication.

```bash
-H "X-API-Key: your-secret-api-key"
```

---

### 1. Get Latest Commits

-   **Endpoint:** `/logs`
-   **Method:** `GET`
-   **Description:** Returns the last 3 commit logs from the configured branch.

-   **Example Request:**
    ```bash
    curl -H "X-API-Key: your-secret-api-key" http://localhost:8080/logs
    ```

-   **Example Response:**
    ```
    a1b2c3d - Author Name, 2 days ago : Fix: some bug
    e4f5g6h - Author Name, 3 days ago : Feat: new feature
    i7j8k9l - Author Name, 4 days ago : Chore: update dependencies
    ```

---

### 2. Get Current Branch

-   **Endpoint:** `/branch`
-   **Method:** `GET`
-   **Description:** Shows the current active branch of the repository.

-   **Example Request:**
    ```bash
    curl -H "X-API-Key: your-secret-api-key" http://localhost:8080/branch
    ```

-   **Example Response:**
    ```
    main
    ```

---

### 3. Update Repository

-   **Endpoint:** `/update`
-   **Method:** `POST` or `GET`
-   **Description:** Updates the repository by checking out the configured branch and pulling the latest changes from the `origin` remote.

-   **Example Request:**
    ```bash
    curl -X POST -H "X-API-Key: your-secret-api-key" http://localhost:8080/update
    ```

-   **Example Response (Success):**
    ```
    Switched to branch 'main'
    Your branch is up to date with 'origin/main'.
    Already up to date.
    ```
-   **Example Response (With Changes):**
    ```
    Switched to branch 'main'
    Your branch is up to date with 'origin/main'.
    Updating a1b2c3d..e4f5g6h
    Fast-forward
     ...
    ```

## License

This project is open-source and available under the [MIT License](LICENSE).
