import os
import time
import subprocess
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

class MyHandler(FileSystemEventHandler):
    def on_modified(self, event):
        # Check if the extension is .asm
        if event.src_path.endswith('.s'):
            if not event.src_path.endswith('compile.bat'):
                print(f'File changed: {event.src_path}. Running compile.bat...')
                # Run the compile.bat script
                subprocess.run([bat_script])

if __name__ == "__main__":
    # Get the directory where the script is located
    folder = os.path.dirname(os.path.abspath(__file__))
    
    # Path to the compile.bat script in the same folder
    bat_script = os.path.join(folder, "compile.bat")
    
    # Check if compile.bat exists
    if not os.path.isfile(bat_script):
        print(f"Error: compile.bat not found in {folder}")
        exit(1)
    
    event_handler = MyHandler()
    observer = Observer()
    observer.schedule(event_handler, folder, recursive=False) # Only watch this folder
    
    # Start the observer
    observer.start()
    print(f"Watching folder: {folder}")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()