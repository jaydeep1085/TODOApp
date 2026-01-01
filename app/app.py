from flask import Flask, render_template, request, redirect, url_for, jsonify
from datetime import datetime
import json
import os

app = Flask(__name__)

# File to store todos
TODOS_FILE = 'todos.json'

def load_todos():
    """Load todos from JSON file"""
    if os.path.exists(TODOS_FILE):
        with open(TODOS_FILE, 'r') as f:
            return json.load(f)
    return []

def save_todos(todos):
    """Save todos to JSON file"""
    with open(TODOS_FILE, 'w') as f:
        json.dump(todos, f, indent=4)

@app.route('/')
def index():
    """Display all todos"""
    todos = load_todos()
    return render_template('index.html', todos=todos)

@app.route('/add', methods=['POST'])
def add_todo():
    """Add a new todo"""
    title = request.form.get('title', '').strip()
    if not title:
        return redirect(url_for('index'))
    
    todos = load_todos()
    new_todo = {
        'id': max([t['id'] for t in todos], default=0) + 1,
        'title': title,
        'completed': False,
        'created_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    }
    todos.append(new_todo)
    save_todos(todos)
    
    return redirect(url_for('index'))

@app.route('/toggle/<int:todo_id>', methods=['POST'])
def toggle_todo(todo_id):
    """Toggle todo completion status"""
    todos = load_todos()
    for todo in todos:
        if todo['id'] == todo_id:
            todo['completed'] = not todo['completed']
            break
    save_todos(todos)
    
    return redirect(url_for('index'))

@app.route('/delete/<int:todo_id>', methods=['POST'])
def delete_todo(todo_id):
    """Delete a todo"""
    todos = load_todos()
    todos = [t for t in todos if t['id'] != todo_id]
    save_todos(todos)
    
    return redirect(url_for('index'))

@app.route('/edit/<int:todo_id>', methods=['POST'])
def edit_todo(todo_id):
    """Edit a todo"""
    title = request.form.get('title', '').strip()
    if not title:
        return redirect(url_for('index'))
    
    todos = load_todos()
    for todo in todos:
        if todo['id'] == todo_id:
            todo['title'] = title
            break
    save_todos(todos)
    
    return redirect(url_for('index'))

@app.route('/clear-completed', methods=['POST'])
def clear_completed():
    """Clear all completed todos"""
    todos = load_todos()
    todos = [t for t in todos if not t['completed']]
    save_todos(todos)
    
    return redirect(url_for('index'))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80, debug=True)
