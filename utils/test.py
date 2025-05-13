#!/usr/bin/env python3

import os
import stat
import argparse
import sys
from datetime import datetime

# ANSI color codes for better readability
class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    BOLD = '\033[1m'
    ENDC = '\033[0m'

# Paths and files to check based on the bash script
CHECKS = {
    "alpinestein_mnt": {"description": "Directory alpinestein_mnt should not exist", "type": "dir"},
    "alpinestein": {"description": "Directory alpinestein should exist", "type": "dir"},
    "alpinestein/root/.ashrc": {"description": "File .ashrc should be copied to root directory", "type": "file"},
    "assets/config.conf": {"description": "File config.conf should exist in assets directory", "type": "file"},
    "assets/profile.sh": {"description": "File profile.sh should exist and be executable", "type": "exec"},
    "assets/issue.ceauron": {"description": "File issue.ceauron should exist in assets", "type": "file"},
    "assets/mods/welcome.sh": {"description": "File welcome.sh should exist in mods directory", "type": "file"},
    "assets/mods/version.sh": {"description": "File version.sh should exist in mods directory", "type": "file"},
    "utils/install.sh": {"description": "Script install.sh should exist and be executable", "type": "exec"},
    "utils/mount.sh": {"description": "Script mount.sh should exist and be executable", "type": "exec"},
    "utils/unmount.sh": {"description": "Script unmount.sh should exist and be executable", "type": "exec"},
    "/etc/resolv.conf": {"description": "File resolv.conf should exist on the host system", "type": "file"},
    "alpinestein/etc/resolv.conf": {"description": "resolv.conf should be copied to alpinestein/etc/", "type": "file"},
    "alpinestein/etc/profile.d/logo.sh": {"description": "logo.sh should be copied to profile.d", "type": "exec"},
    "alpinestein/etc/profile.d/welcome.sh": {"description": "welcome.sh should be copied to profile.d", "type": "exec"},
    "alpinestein/etc/profile.d/version.sh": {"description": "version.sh should be copied to profile.d", "type": "exec"}
}
# can also add "dir_not_exist" if shouldbt present yet

def check_path(path, check_info, root_dir=''):
    """Check if a file or directory exists and has the right properties."""
    check_type = check_info["type"]
    description = check_info["description"]
    
    # If root_dir is provided, use it to create an absolute path
    if root_dir:
        abs_path = os.path.join(root_dir, path)
    else:
        abs_path = os.path.abspath(path)
    
    result = {
        "path": path, 
        "description": description, 
        "status": "FAIL",
        "details": "",
        "abs_path": abs_path
    }
    
    # Check based on type
    if check_type == "dir_not_exist":
        if not os.path.exists(abs_path):
            result["status"] = "PASS"
        else:
            result["details"] = "Directory exists but should not"
            
    elif check_type == "dir":
        if os.path.exists(abs_path) and os.path.isdir(abs_path):
            result["status"] = "PASS"
        else:
            result["details"] = "Directory does not exist"
            
    elif check_type == "file":
        if os.path.exists(abs_path) and os.path.isfile(abs_path):
            result["status"] = "PASS"
        else:
            result["details"] = "File does not exist"
            
    elif check_type == "exec":
        if os.path.exists(abs_path) and os.path.isfile(abs_path):
            if os.access(abs_path, os.X_OK):
                result["status"] = "PASS"
            else:
                result["details"] = "File exists but is not executable"
        else:
            result["details"] = "File does not exist"
    
    return result

def test_paths(root_dir=None, verbose=False):
    """Test all paths defined in CHECKS."""
    if not root_dir:
        root_dir = os.path.abspath(os.getcwd())  # Get current working directory
    
    if verbose:
        print(f"{Colors.BLUE}Root Directory: {root_dir}{Colors.ENDC}")
    
    results = []
    
    # Loop through all checks and validate each
    for path, check_info in CHECKS.items():
        if verbose:
            print(f"Checking: {path}")
        
        result = check_path(path, check_info, root_dir)
        results.append(result)
        
    return results

def print_results(results, verbose=False):
    """Print the results in a nice format."""
    # Count statistics
    total = len(results)
    passed = sum(1 for r in results if r["status"] == "PASS")
    failed = total - passed
    
    # Print header
    print(f"\n{Colors.BOLD}AlpineStein Test Results{Colors.ENDC}")
    print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"{'=' * 80}")
    print(f"{'Path':<60} {'Status':<10} {'Description'}")
    print(f"{'-' * 80}")
    
    # Print each result
    for result in results:
        status_color = Colors.GREEN if result["status"] == "PASS" else Colors.RED
        status_display = f"{status_color}{result['status']}{Colors.ENDC}"
        
        print(f"{result['path']:<60} {status_display:<10} {result['description']}")
        
        # Print details for failures if verbose
        if verbose and result["status"] == "FAIL" and result["details"]:
            print(f"  {Colors.RED}→ {result['details']} ({result['abs_path']}){Colors.ENDC}")
    
    # Print summary
    print(f"{'-' * 80}")
    print(f"Summary: {Colors.GREEN}{passed} PASS{Colors.ENDC}, {Colors.RED}{failed} FAIL{Colors.ENDC} (Total: {total})")

def main():
    parser = argparse.ArgumentParser(description='AlpineStein Project Test Script')
    parser.add_argument('-v', '--verbose', action='store_true', help='Enable verbose output')
    parser.add_argument('-d', '--directory', type=str, help='Specify project root directory')
    args = parser.parse_args()
    
    # Run the tests
    root_dir = args.directory if args.directory else None
    results = test_paths(root_dir, args.verbose)
    print_results(results, args.verbose)
    
    # Return appropriate exit code
    failed = sum(1 for r in results if r["status"] == "FAIL")
    sys.exit(1 if failed > 0 else 0)

if __name__ == "__main__":
    main()