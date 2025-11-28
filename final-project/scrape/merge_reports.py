#!/usr/bin/env python3
"""
Script to merge hackerone_reports_output.json with hackerone_reports_content_output.json
"""

import json
import sys
from typing import Dict, List, Any

def load_json_file(filepath: str) -> List[Dict[str, Any]]:
    """Load and parse a JSON file"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"Error: File {filepath} not found")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in {filepath}: {e}")
        sys.exit(1)

def create_url_to_content_map(content_data: List[Dict[str, Any]]) -> Dict[str, str]:
    """Create a mapping from URL to original_report content"""
    url_to_content = {}
    for item in content_data:
        if 'url' in item and 'original_report' in item:
            url_to_content[item['url']] = item['original_report']
    return url_to_content

def merge_reports(reports_data: List[Dict[str, Any]], url_to_content: Dict[str, str]) -> List[Dict[str, Any]]:
    """Merge the reports data with content data"""
    merged_data = []
    
    for report in reports_data:
        # Create a copy of the report
        merged_report = report.copy()
        
        # Add the original_report content if available
        url = report.get('url')
        if url and url in url_to_content:
            merged_report['original_report'] = url_to_content[url]
        else:
            # If no content found, add empty string or None
            merged_report['original_report'] = ""
        
        merged_data.append(merged_report)
    
    return merged_data

def main():
    # File paths
    reports_file = 'hackerone_reports_output.json'
    content_file = 'hackerone_reports_content_output.json'
    output_file = 'hackerone_reports_combined.json'
    
    print("Loading reports data...")
    reports_data = load_json_file(reports_file)
    print(f"Loaded {len(reports_data)} reports")
    
    print("Loading content data...")
    content_data = load_json_file(content_file)
    print(f"Loaded {len(content_data)} content entries")
    
    print("Creating URL to content mapping...")
    url_to_content = create_url_to_content_map(content_data)
    print(f"Created mapping for {len(url_to_content)} URLs")
    
    print("Merging data...")
    merged_data = merge_reports(reports_data, url_to_content)
    
    print("Saving merged data...")
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(merged_data, f, indent=2, ensure_ascii=False)
    
    print(f"Successfully merged data and saved to {output_file}")
    print(f"Final output contains {len(merged_data)} reports")
    
    # Show some statistics
    reports_with_content = sum(1 for report in merged_data if report.get('original_report'))
    print(f"Reports with content: {reports_with_content}")
    print(f"Reports without content: {len(merged_data) - reports_with_content}")

if __name__ == "__main__":
    main()
