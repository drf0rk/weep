#!/bin/bash
# Full script: setup_and_run.sh (Automated based on new guide)

# Log files for debugging startup
LOG_FILE="/workspace/onstart.log"
ROOP_LOG="/workspace/roop.log" # Log specifically for the run.py output

# --- Define Repository Details ---
# Using the directory name from the new repo URL
REPO_DIR="/workspace/Roop-Unleashed-Runpod"
# New Repo URL from the guide
REPO_URL="https://github.com/norby777/Roop-Unleashed-Runpod.git"
VENV_DIR="venv" # Name of the virtual environment directory
# --- End Definitions ---

echo "Starting Automated On-Start Script (New Guide Version)..." > $LOG_FILE
date >> $LOG_FILE

# Navigate to workspace first
cd /workspace || { echo "ERROR: Failed to cd into /workspace" >> $LOG_FILE; exit 1; }
echo "Ensuring repository exists at $REPO_DIR..." >> $LOG_FILE

# Check if repo dir exists, if not, clone it
if [ ! -d "$REPO_DIR" ]; then
    echo "Repository directory not found. Cloning '$REPO_URL' into '$REPO_DIR'..." >> $LOG_FILE
    git clone "$REPO_URL" "$REPO_DIR" >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to clone repository." >> $LOG_FILE
        exit 1
    fi
    echo "Repository cloned successfully." >> $LOG_FILE
else
    echo "Repository directory '$REPO_DIR' already exists." >> $LOG_FILE
    # Optional: git pull if you want updates
    # echo "Attempting git pull..." >> $LOG_FILE
    # ( cd "$REPO_DIR" && git pull origin main >> $LOG_FILE 2>&1 ) # Or appropriate branch
    # echo "Git pull attempted." >> $LOG_FILE
fi

# Now, cd into the repository
cd "$REPO_DIR" || { echo "ERROR: Failed to cd into '$REPO_DIR' after clone/check." >> $LOG_FILE; exit 1; }
echo "Changed directory to $(pwd)" >> $LOG_FILE

# --- Check for venv and Run Setup ONLY if it doesn't exist ---
# Based on Step 2 (Optional) and Step 3 from the guide
if [ ! -d "$VENV_DIR/bin" ]; then
    echo "Virtual environment ($VENV_DIR) not found. Performing one-time setup..." >> $LOG_FILE
    date >> $LOG_FILE

    # Step 2: Install virtualenv and create venv
    echo "Installing virtualenv..." >> $LOG_FILE
    pip install virtualenv >> $LOG_FILE 2>&1
    # Don't exit on failure here, maybe it's already installed system-wide

    echo "Creating venv ($VENV_DIR)..." >> $LOG_FILE
    python -m venv "$VENV_DIR" >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then echo "ERROR: Failed to create venv." >> $LOG_FILE; exit 1; fi

    # Activate venv for the setup part
    echo "Activating venv for setup..." >> $LOG_FILE
    source "$VENV_DIR/bin/activate" >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then echo "ERROR: Failed to activate venv during setup." >> $LOG_FILE; exit 1; fi

    # Step 3: Install requirements and specific packages
    echo "Installing requirements.txt..." >> $LOG_FILE
    pip install -r requirements.txt >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then echo "ERROR: Failed during pip install -r requirements.txt." >> $LOG_FILE; exit 1; fi

    echo "Installing system packages (ffmpeg)..." >> $LOG_FILE
    apt-get update >> $LOG_FILE 2>&1
    apt-get install -y ffmpeg >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then echo "WARNING: Failed to install ffmpeg via apt-get." >> $LOG_FILE; fi # Warning only

    echo "Pinning pydantic version..." >> $LOG_FILE
    pip install --force-reinstall pydantic==2.10.6 >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then echo "ERROR: Failed during pydantic reinstall." >> $LOG_FILE; exit 1; fi

    # Deactivate venv after setup
    deactivate >> $LOG_FILE 2>&1
    echo "One-time setup complete." >> $LOG_FILE
    date >> $LOG_FILE
else
    echo "Virtual environment ($VENV_DIR) found. Skipping setup." >> $LOG_FILE
fi

# --- Stop old processes ---
# Important if restarting the instance
echo "Stopping potentially old run.py processes..." >> $LOG_FILE
pkill -f "python run.py"
sleep 2

# --- Activate virtual environment (for running apps) ---
echo "Activating venv for running application..." >> $LOG_FILE
source "$VENV_DIR/bin/activate" >> $LOG_FILE 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to activate venv before launching app." >> $LOG_FILE
    exit 1
fi
echo "Virtualenv activated." >> $LOG_FILE

# --- Start Roop UI (run.py) ---
# Guide runs 'python run.py' directly. To make it accessible externally
# and run in background, we add --listen, --port 7860, nohup, >> log, &
echo "Launching Roop UI (run.py)..." >> $LOG_FILE
nohup python run.py >> $ROOP_LOG 2>&1 &
ROOP_PID=$!
echo "Roop UI launched with PID $ROOP_PID. Check $ROOP_LOG for details." >> $LOG_FILE

echo "Automated On-Start Script (New Guide Version) finished." >> $LOG_FILE
date >> $LOG_FILE
exit 0
