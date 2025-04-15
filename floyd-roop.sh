#!/bin/bash
# Full script: setup_and_run.sh (with automated setup)

# Log files for debugging startup
LOG_FILE="/workspace/onstart.log"
JUPYTER_LOG="/workspace/jupyter.log"
ROOP_LOG="/workspace/roop.log"

# --- Define Repository Details ---
REPO_DIR="/workspace/Roop-Unleashed-Runpod"
REPO_URL="https://github.com/drf0rk/weep"
VENV_DIR="venv" # Name of the virtual environment directory
# --- End Definitions ---

echo "Starting Automated On-Start Script (setup_and_run.sh)..." > $LOG_FILE
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
    # Optional: Add 'git pull' here if you want updates on restart
    # echo "Attempting git pull..." >> $LOG_FILE
    # ( cd "$REPO_DIR" && git pull origin main >> $LOG_FILE 2>&1 )
    # echo "Git pull attempted." >> $LOG_FILE
fi

# Now, cd into the repository
cd "$REPO_DIR" || { echo "ERROR: Failed to cd into '$REPO_DIR' after clone/check." >> $LOG_FILE; exit 1; }
echo "Changed directory to $(pwd)" >> $LOG_FILE

# --- Check for venv and Run Setup ONLY if it doesn't exist ---
if [ ! -d "$VENV_DIR/bin" ]; then
    echo "Virtual environment ($VENV_DIR) not found. Performing one-time setup..." >> $LOG_FILE
    date >> $LOG_FILE

    # Install virtualenv package
    echo "Installing virtualenv..." >> $LOG_FILE
    pip install virtualenv >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then echo "ERROR: Failed to install virtualenv." >> $LOG_FILE; exit 1; fi

    # Create the virtual environment
    echo "Creating venv..." >> $LOG_FILE
    python -m venv "$VENV_DIR" >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then echo "ERROR: Failed to create venv." >> $LOG_FILE; exit 1; fi

    # Activate venv for the setup part of THIS script execution
    echo "Activating venv for setup..." >> $LOG_FILE
    source "$VENV_DIR/bin/activate" >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then echo "ERROR: Failed to activate venv during setup." >> $LOG_FILE; exit 1; fi

    # Install requirements
    echo "Installing requirements.txt..." >> $LOG_FILE
    pip install -r requirements.txt >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then echo "ERROR: Failed during pip install -r requirements.txt." >> $LOG_FILE; exit 1; fi

    # Install system packages
    echo "Installing system packages (ffmpeg)..." >> $LOG_FILE
    apt-get update >> $LOG_FILE 2>&1
    apt-get install -y ffmpeg >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then echo "ERROR: Failed to install ffmpeg." >> $LOG_FILE; exit 1; fi

    # Install/upgrade specific packages
    echo "Installing/upgrading specific pip packages..." >> $LOG_FILE
    pip install --upgrade gradio --force >> $LOG_FILE 2>&1
    pip install --upgrade fastapi pydantic >> $LOG_FILE 2>&1
    pip install "numpy<2.0" >> $LOG_FILE 2>&1
    pip install --force-reinstall pydantic==2.10.6 >> $LOG_FILE 2>&1
    pip install onnxruntime-gpu==1.19.0 >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then echo "ERROR: Failed during specific pip package installs." >> $LOG_FILE; exit 1; fi

    # Deactivate venv after setup (optional, good practice)
    deactivate >> $LOG_FILE 2>&1
    echo "One-time setup complete." >> $LOG_FILE
    date >> $LOG_FILE
else
    echo "Virtual environment ($VENV_DIR) found. Skipping setup." >> $LOG_FILE
fi

# --- Stop old processes ---
# (Run this every time, regardless of setup)
echo "Stopping old processes..." >> $LOG_FILE
pkill -f "jupyter-lab"
pkill -f "python run.py"
sleep 2

# --- Activate virtual environment (for running apps) ---
# This needs to run every time the script runs
echo "Activating venv for running applications..." >> $LOG_FILE
source "$VENV_DIR/bin/activate" >> $LOG_FILE 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to activate venv before launching apps." >> $LOG_FILE
    exit 1
fi
echo "Virtualenv activated." >> $LOG_FILE

# --- Start JupyterLab ---
echo "Launching JupyterLab..." >> $LOG_FILE
nohup jupyter lab --port=8080 --ip=0.0.0.0 --no-browser --allow-root --notebook-dir=/workspace/ >> $JUPYTER_LOG 2>&1 &
JUPYTER_PID=$!
echo "JupyterLab launched with PID $JUPYTER_PID. Check $JUPYTER_LOG for token and details." >> $LOG_FILE
sleep 5

# --- Start Roop UI ---
echo "Launching Roop UI (run.py) using venv python..." >> $LOG_FILE
# Explicitly use the python executable from the venv directory
# Note: No need for --listen --port if using the config file modification method
nohup "$VENV_DIR/bin/python" run.py >> $ROOP_LOG 2>&1 &
ROOP_PID=$!
echo "Roop UI launched with PID $ROOP_PID using $VENV_DIR/bin/python. Check $ROOP_LOG for details." >> $LOG_FILE

echo "Automated On-Start Script finished." >> $LOG_FILE
date >> $LOG_FILE
exit 0
