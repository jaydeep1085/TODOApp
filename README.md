# TODO App - Flask Based

A simple and elegant TODO application built with Flask. Keep track of your tasks with ease!! 

## Features

✨ **Simple & Clean UI** - Intuitive interface for managing your todos  
✅ **Add Tasks** - Quickly add new tasks to your list  
✓ **Mark Complete** - Check off completed tasks  
🗑️ **Delete Tasks** - Remove tasks you no longer need  
📊 **Statistics** - View your progress with task counters  
💾 **Persistent Storage** - Tasks are saved to JSON file  
📱 **Responsive Design** - Works on desktop and mobile devices

## Project Structure :

```
TODOApp/
├── app/
│   ├── app.py              # Main Flask application
│   ├── templates/
│   │   └── index.html      # HTML template
│   └── static/
│       └── style.css       # CSS styling
├── requirements.txt        # Python dependencies
└── README.md              # This file
```

## Installation & Setup

### 1. Clone or Download the Project
```bash
cd TODOApp
```

### 2. Create a Virtual Environment (Recommended)
```bash
python -m venv venv

# Activate virtual environment
# On Windows:
venv\Scripts\activate
# On macOS/Linux:
source venv/bin/activate
```

### 3. Install Dependencies
```bash
pip install -r requirements.txt
```

## Running the App

1. Navigate to the project directory (if not already there)
2. Activate the virtual environment (if using one)
3. Run the Flask app:
```bash
cd app
python app.py
```

4. Open your browser and visit:
```
http://localhost:5000
```


## Usage

- **Add a Task**: Type in the input field and click "Add Task" or press Enter
- **Mark Complete**: Click the checkbox next to a task to mark it as complete
- **Delete a Task**: Click the "Delete" button to remove a task
- **Clear Completed**: Remove all completed tasks at once with the "Clear Completed Tasks" button

## Technologies Used

- **Flask 3.0.0** - Lightweight Python web framework
- **HTML5** - Markup structure
- **CSS3** - Responsive styling
- **JSON** - Data storage


