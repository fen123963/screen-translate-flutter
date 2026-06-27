import json
import os

DICT_DIR = r'd:\Trae\BC\识别\screen_translator\assets\dict'

files_to_check = [
    ('cet6_vocabulary.json', 'object'),
    ('cet6_vocabulary_ac.json', 'array'),
    ('cet6_vocabulary_df.json', 'array'),
    ('cet6_vocabulary_gi.json', 'array'),
    ('cet6_vocabulary_jl.json', 'array'),
    ('cet6_vocabulary_mo.json', 'array'),
    ('cet6_vocabulary_pr.json', 'array'),
    ('cet6_vocabulary_su.json', 'array'),
    ('cet6_vocabulary_vz.json', 'array'),
    ('cet6_vocabulary_dz.json', 'object'),
    ('cet6_phrases.json', 'object'),
    ('metadata.json', 'object'),
]

def validate_json_file(filepath, expected_format):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        if expected_format == 'array':
            if not isinstance(data, list):
                return False, f"Expected array format, got {type(data).__name__}"
            count = len(data)
        else:
            if not isinstance(data, dict):
                return False, f"Expected object format, got {type(data).__name__}"
            count = len(data.get('entries', []))
        
        entries_list = data if expected_format == 'array' else data.get('entries', [])
        
        for entry in entries_list:
            word = entry.get('word') or entry.get('phrase')
            if not word:
                return False, f"Missing 'word' or 'phrase' field in entry"
            
            definitions = entry.get('definitions') or entry.get('definition')
            if not definitions:
                return False, f"Missing 'definitions' or 'definition' field in entry: {word}"
        
        return True, f"OK - {count} entries"
    except json.JSONDecodeError as e:
        return False, f"JSON parse error: {e}"
    except Exception as e:
        return False, f"Error: {e}"

def main():
    print("=" * 60)
    print("词库文件完整性验证")
    print("=" * 60)
    
    total_entries = 0
    errors = []
    
    for filename, expected_format in files_to_check:
        filepath = os.path.join(DICT_DIR, filename)
        if not os.path.exists(filepath):
            errors.append(f"文件不存在: {filename}")
            continue
        
        success, message = validate_json_file(filepath, expected_format)
        status = "PASS" if success else "FAIL"
        
        if success:
            parts = message.split(' - ')
            if len(parts) > 1:
                count = int(parts[1].split()[0])
                total_entries += count
        
        print(f"[{status}] {filename}: {message}")
        if not success:
            errors.append(f"{filename}: {message}")
    
    print("=" * 60)
    print(f"总词条数: {total_entries}")
    
    if errors:
        print("\n发现错误:")
        for err in errors:
            print(f"  - {err}")
        return 1
    else:
        print("\n所有验证通过!")
        return 0

if __name__ == '__main__':
    exit(main())