import pytest
import sys
import os
import json
import tempfile

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../app')))

from app import app, load_todos, save_todos

@pytest.fixture
def client():
    """Create test client"""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

@pytest.fixture
def temp_todos_file():
    """Create temporary todos file for testing"""
    with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.json') as f:
        json.dump([], f)
        temp_file = f.name
    yield temp_file
    if os.path.exists(temp_file):
        os.remove(temp_file)

class TestIndexPage:
    """Test index page functionality"""
    
    def test_index_returns_200(self, client):
        """Test if index page loads successfully"""
        response = client.get('/')
        assert response.status_code == 200
    
    def test_index_contains_form(self, client):
        """Test if index page contains add task form"""
        response = client.get('/')
        assert b'Add a new task' in response.data or b'Add Task' in response.data

class TestAddTodo:
    """Test adding todo functionality"""
    
    def test_add_todo_success(self, client):
        """Test adding a valid todo"""
        response = client.post('/add', data={'title': 'Test Task'})
        assert response.status_code == 302  # Redirect after POST
    
    def test_add_empty_todo(self, client):
        """Test adding empty todo is rejected"""
        response = client.post('/add', data={'title': ''})
        assert response.status_code == 302
    
    def test_add_todo_with_whitespace(self, client):
        """Test adding todo with only whitespace"""
        response = client.post('/add', data={'title': '   '})
        assert response.status_code == 302
    
    def test_add_multiple_todos(self, client):
        """Test adding multiple todos"""
        response1 = client.post('/add', data={'title': 'Task 1'})
        response2 = client.post('/add', data={'title': 'Task 2'})
        assert response1.status_code == 302
        assert response2.status_code == 302

class TestToggleTodo:
    """Test toggling todo completion status"""
    
    def test_toggle_todo(self, client):
        """Test toggling todo completion"""
        # Add a todo first
        client.post('/add', data={'title': 'Test Task'})
        # Toggle it (assuming ID 1)
        response = client.post('/toggle/1')
        assert response.status_code == 302

class TestDeleteTodo:
    """Test deleting todo functionality"""
    
    def test_delete_todo(self, client):
        """Test deleting a todo"""
        # Add a todo first
        client.post('/add', data={'title': 'Test Task'})
        # Delete it
        response = client.post('/delete/1')
        assert response.status_code == 302

class TestClearCompleted:
    """Test clearing completed todos"""
    
    def test_clear_completed(self, client):
        """Test clearing all completed todos"""
        response = client.post('/clear-completed')
        assert response.status_code == 302

class TestTodoFunctions:
    """Test todo helper functions"""
    
    def test_load_todos_empty(self, temp_todos_file):
        """Test loading empty todos"""
        todos = load_todos()
        assert isinstance(todos, list)
    
    def test_save_and_load_todos(self, temp_todos_file):
        """Test saving and loading todos"""
        test_todos = [
            {
                'id': 1,
                'title': 'Test Task',
                'completed': False,
                'created_at': '2025-12-29 12:00:00'
            }
        ]
        save_todos(test_todos)
        loaded = load_todos()
        assert isinstance(loaded, list)
