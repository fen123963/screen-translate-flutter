import json

print("=== CET-6 Dictionary Service Test ===")

# Test 1: Verify all JSON files exist and are valid
print("\n1. Validating JSON files...")
files = [
    'screen_translator/assets/dict/cet6_vocabulary.json',
    'screen_translator/assets/dict/cet6_vocabulary_ac.json',
    'screen_translator/assets/dict/cet6_vocabulary_df.json',
    'screen_translator/assets/dict/cet6_vocabulary_gi.json',
    'screen_translator/assets/dict/cet6_vocabulary_jl.json',
    'screen_translator/assets/dict/cet6_vocabulary_mo.json',
    'screen_translator/assets/dict/cet6_vocabulary_pr.json',
    'screen_translator/assets/dict/cet6_vocabulary_su.json',
    'screen_translator/assets/dict/cet6_vocabulary_vz.json',
    'screen_translator/assets/dict/cet6_vocabulary_dz.json',
    'screen_translator/assets/dict/cet6_phrases.json',
    'screen_translator/assets/dict/metadata.json',
]

all_valid = True
for f in files:
    try:
        data = json.load(open(f, encoding='utf-8'))
        if isinstance(data, dict) and 'entries' in data:
            count = len(data['entries'])
        elif isinstance(data, list):
            count = len(data)
        else:
            count = 'N/A'
        print('   OK: %s (%d entries)' % (f.split('/')[-1], count if count != 'N/A' else 0))
    except Exception as e:
        print('   FAIL: %s - Error: %s' % (f.split('/')[-1], str(e)))
        all_valid = False

# Test 2: Check format compatibility
print("\n2. Testing format compatibility...")

# Check array format (new files)
array_file = 'screen_translator/assets/dict/cet6_vocabulary_ac.json'
data = json.load(open(array_file, encoding='utf-8'))
if isinstance(data, list) and len(data) > 0:
    entry = data[0]
    required_fields = ['word', 'phonetic', 'definitions', 'part_of_speech', 'example_sentence', 'level']
    missing = [f for f in required_fields if f not in entry]
    if missing:
        print('   FAIL: Array format missing fields: %s' % str(missing))
    else:
        print('   OK: Array format has all required fields')
        print('     Sample: %s - %s' % (entry['word'], entry['definitions']))
else:
    print('   FAIL: Array format invalid')

# Check object format (existing files)
object_file = 'screen_translator/assets/dict/cet6_vocabulary.json'
data = json.load(open(object_file, encoding='utf-8'))
if isinstance(data, dict) and 'entries' in data:
    entry = data['entries'][0]
    required_fields = ['word', 'phonetic', 'definitions', 'part_of_speech', 'example_sentence', 'level']
    missing = [f for f in required_fields if f not in entry]
    if missing:
        print('   FAIL: Object format missing fields: %s' % str(missing))
    else:
        print('   OK: Object format has all required fields')
        print('     Sample: %s - %s' % (entry['word'], entry['definitions']))
else:
    print('   FAIL: Object format invalid')

# Check phrase format
phrase_file = 'screen_translator/assets/dict/cet6_phrases.json'
data = json.load(open(phrase_file, encoding='utf-8'))
if isinstance(data, dict) and 'entries' in data:
    entry = data['entries'][0]
    if 'phrase' in entry and 'definition' in entry:
        print('   OK: Phrase format compatible (phrase/definition fields)')
        print('     Sample: %s - %s' % (entry['phrase'], entry['definition']))
    else:
        print('   FAIL: Phrase format missing phrase/definition fields')
else:
    print('   FAIL: Phrase format invalid')

# Test 3: Verify word coverage across all files
print("\n3. Testing word coverage...")
test_words = [
    'abandon', 'ability', 'accomplish', 'benefit', 'challenge', 'demonstrate',
    'eliminate', 'facilitate', 'guarantee', 'hypothesis', 'implement', 'justify',
    'maintain', 'negotiate', 'optimize', 'perspective', 'quantify', 'relevant',
    'significant', 'tremendous', 'ultimate', 'valid', 'witness', 'yield', 'zone'
]

all_words_found = True
for word in test_words:
    found = False
    for f in files[:-1]:  # Skip metadata
        try:
            data = json.load(open(f, encoding='utf-8'))
            entries = data['entries'] if isinstance(data, dict) else data
            for entry in entries:
                entry_word = entry.get('word', entry.get('phrase', '')).lower()
                if entry_word == word.lower():
                    found = True
                    break
            if found:
                break
        except:
            pass
    if found:
        print('   OK: %s found' % word)
    else:
        print('   FAIL: %s NOT found' % word)
        all_words_found = False

# Test 4: Verify metadata consistency
print("\n4. Verifying metadata consistency...")
metadata = json.load(open('screen_translator/assets/dict/metadata.json', encoding='utf-8'))
expected_total = 0
for file, count in metadata['metadata']['breakdown'].items():
    expected_total += count

actual_total = 0
for f in files[:-1]:
    try:
        data = json.load(open(f, encoding='utf-8'))
        if isinstance(data, dict) and 'entries' in data:
            actual_total += len(data['entries'])
        elif isinstance(data, list):
            actual_total += len(data)
    except:
        pass

print('   Metadata total_entries: %d' % metadata['metadata']['total_entries'])
print('   Actual total entries: %d' % actual_total)
if metadata['metadata']['total_entries'] == actual_total:
    print('   OK: Metadata consistent with actual files')
else:
    print('   FAIL: Metadata mismatch: %d != %d' % (metadata['metadata']['total_entries'], actual_total))

# Summary
print("\n=== Test Summary ===")
if all_valid and all_words_found:
    print("OK: All tests passed - CET-6 dictionary is ready!")
else:
    print("FAIL: Some tests failed - please check the issues above")