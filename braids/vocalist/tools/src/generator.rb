require 'json'

defaults = [
    "hello",
    "electronic",
    "robot",
    "yaaaah",
    "harder",
    "faster",
    "better",
    "stronger",
    "techno",
    "punk music",
    "hacker",
    "bass",
    "activate laser cannon",
    "baby girl",
    "crush kill destroy",
    "swag",
    "asylum",
    "cryptography",
    "quixotic",
    "electronic",
    "enigmatic",
    "galapagos",
    "defribrillate",
    "propulsion",
    "supernova",
    "climactic",
    "exfoliate",
    "synchronicity",
    "minimalism",
    "spherical",
    "filibuster",
    "ottawa",
    "and i will always love you",
    "im singing in the rain",
    "what a glorious feeling im happy again",
    "the beauty of the baud",
    "doo",
    "la",
    "dough",
    "ray",
    "me",
    "fah",
    "so",
    "la",
    "tee",
    "baybee",
    "oooh",
    "aaaah"
]

if ARGV.length != 1
  puts "run as ./generator.rb <wordlist file> where wordlist file is a text file with one word per line"
  puts "file can be up to 64 words."
  exit 1
end

words = File.read(ARGV[0]).split("\n").reject { |w| w.empty? }
filler = words.count % 16

if filler != 0
  filler = 16 - filler
end

words += defaults.first(filler)

banks = words.each_slice(16).to_a

def save(filename, data)
  File.write(filename, data.to_json)
end

def generate_phoneme(word)
  return JSON.parse(`./parser #{word}`)
end

def rle(arr)
  result = []
  el = arr.shift
  count = 1
  arr.each do |item|
    if item == el
      count += 1
    else
      result << count
      result << el
      el = item
      count = 1
    end
  end
  result << count
  result << el
  result
end

voiceTables = %w(frequency1 frequency2 frequency3 pitches amplitude1 amplitude2 amplitude3 sampledConsonantFlag)
phonemes = {}

# build cache
banks.each_with_index do |words, bank_number|
  words.each do |word, word_number|
    if phonemes[word].nil?
      phonemes[word] = generate_phoneme(word)
      voiceTables.each do |table|
        phonemes[word][table] = rle(phonemes[word][table])
      end
    end
  end
end

wordpos = {}
doubleAbsorbPos = {}

index = 0

# generate data blob + indices
File.open("wordlist.cc", 'w') do |file|
  file.write('''#include "wordlist.h"
// This file is autogenerated by running `ruby ./words/words.rb`

const unsigned char data[] = {
''')

  # output data
  banks.each_with_index do |words, bank_number|
    words.each do |word, word_number|
      wordpos[word] = index

      # since we're RLE we need to write the offsets into data to find the start
      # of each table within the voice data.
      tableLengths = voiceTables.map do |table|
        phonemes[word][table].size
      end

      if tableLengths.any? {|t| t > 255}
        puts "Error: word #{word} generated table too long, try shortening it"
        exit 1
      end

      file.write(tableLengths.join(", ") + ", ")
      index += tableLengths.size

      voiceTables.each do |table|
        if phonemes[word][table] == nil
	  puts "Error: word #{word} missing table #{table}"
	  exit 1
        end
        compressed = phonemes[word][table]
        file.write(compressed.join(", "))
        file.write(', ')
        index += compressed.size
      end
      file.write "// #{word}\n"
    end
  end
  file.write("};\n\n")

  file.write("const unsigned int wordpos[#{banks.count}][#{banks[0].count}] = {\n")
  banks.each_with_index do |bank, bank_number|
    file.write("{")
    file.write(bank.map { |word| wordpos[word] }.join(', '))
    file.write("},\n")
  end
  file.write("};\n")

  # output data
  index = 0
  file.write('const unsigned char doubleAbsorbOffset[] = {')

  banks.each_with_index do |words, bank_number|
    words.each do |word, word_number|
      doubleAbsorbPos[word] = index
      file.write(phonemes[word]['doubleAbsorbOffset'].join(", "))
      count = phonemes[word]['doubleAbsorbOffset'].count
      if count > 0
        file.write(', ')
        index += count 
        file.write "// #{word}\n"
      end
    end
  end
  file.write("};\n\n")

  file.write("const unsigned char doubleAbsorbLen[#{banks.count}][#{banks[0].count}] = {\n")
  banks.each_with_index do |bank, bank_number|
    file.write("{")
    file.write(bank.map { |word| phonemes[word]['doubleAbsorbOffset'].count }.join(', '))
    file.write("},\n")
  end
  file.write("};\n")

  file.write("const unsigned short doubleAbsorbPos[#{banks.count}][#{banks[0].count}] = {\n")
  banks.each_with_index do |bank, bank_number|
    file.write("{")
    file.write(bank.map { |word| doubleAbsorbPos[word] }.join(', '))
    file.write("},\n")
  end
  file.write("};\n")
end

# generate data blob + indices
File.open("wordlist.h", 'w') do |file|
  file.write("""
#ifndef __WORDLIST_H__
#define __WORDLIST_H__

// This file is autogenerated by running `ruby tools/generator.rb`

extern const unsigned char data[];
extern const unsigned short wordlen[#{banks.count}][#{banks[0].count}];
extern const unsigned int wordpos[#{banks.count}][#{banks[0].count}];

extern const unsigned char doubleAbsorbOffset[];
extern const unsigned char doubleAbsorbLen[#{banks.count}][#{banks[0].count}];
extern const unsigned short doubleAbsorbPos[#{banks.count}][#{banks[0].count}];

#define NUM_BANKS #{banks.count}
#define NUM_WORDS #{banks[0].count}

#endif
""")
end
