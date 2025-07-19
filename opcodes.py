opcodes = [
    ('ORItoCCR', '0000000000111100'),
    ('ORItoSR', '0000000001111100'),
    ('ANDItoCCR', '0000001000111100'),
    ('ANDItoSR', '0000001001111100'),
    ('EORItoCCR', '0000101000111100'),
    ('EORItoSR', '0000101001111100'),
    ('ILLEGAL', '0100101011111100'),
    ('RESET', '0100111001110000'),
    ('NOP', '0100111001110001'),
    ('STOP', '0100111001110010'),
    ('RTE', '0100111001110011'),
    ('RTS', '0100111001110101'),
    ('TRAPV', '0100111001110110'),
    ('RTR', '0100111001110111'),
    ('SWAP', '0100100001000xxx'),
    ('LINK', '0100111001010xxx'),
    ('UNLK', '0100111001011xxx'),
    ('EXTw', '0100100010000xxx'),
    ('EXTl', '0100100011000xxx'),
    ('TRAP', '010011100100xxxx'),
    ('MOVEUSP', '010011100110xxxx'),
    ('BTSTr', '000010000000xxxx'),
    ('BCHGr', '000010000100xxxx'),
    ('BCLRr', '000010001000xxxx'),
    ('BSETr', '000010001100xxxx'),
    ('BTSTm', '0000100000xxxxxx'),
    ('BCHGm', '0000100001xxxxxx'),
    ('BCLRm', '0000100010xxxxxx'),
    ('BSETm', '0000100011xxxxxx'),
    ('MOVEfromSR', '0100000011xxxxxx'),
    ('MOVEtoCCR', '0100010011xxxxxx'),
    ('MOVEtoSR', '0100011011xxxxxx'),
    ('NBCD', '0100100000xxxxxx'),
    ('PEA', '0100100001xxxxxx'),
    ('TAS', '0100101011xxxxxx'),
    ('JSR', '0100111010xxxxxx'),
    ('JMP', '0100111011xxxxxx'),
    ('ASRm', '1110000011xxxxxx'),
    ('LSRm', '1110001011xxxxxx'),
    ('ROXRm', '1110010011xxxxxx'),
    ('RORm', '1110011011xxxxxx'),
    ('ASLm', '1110000111xxxxxx'),
    ('LSLm', '1110001111xxxxxx'),
    ('ROXLm', '1110010111xxxxxx'),
    ('ROLm', '1110011111xxxxxx'),
    ('ORIb', '0000000000xxxxxx'),
    ('ORIw', '0000000001xxxxxx'),
    ('ORIl', '0000000010xxxxxx'),
    ('ANDIb', '0000001000xxxxxx'),
    ('ANDIw', '0000001001xxxxxx'),
    ('ANDIl', '0000001010xxxxxx'),
    ('SUBIb', '0000010000xxxxxx'),
    ('SUBIw', '0000010001xxxxxx'),
    ('SUBIl', '0000010010xxxxxx'),
    ('ADDIb', '0000011000xxxxxx'),
    ('ADDIw', '0000011001xxxxxx'),
    ('ADDIl', '0000011010xxxxxx'),
    ('EORIb', '0000101000xxxxxx'),
    ('EORIw', '0000101001xxxxxx'),
    ('EORIl', '0000101010xxxxxx'),
    ('CMPIb', '0000110000xxxxxx'),
    ('CMPIw', '0000110001xxxxxx'),
    ('CMPIl', '0000110010xxxxxx'),
    ('CLRb', '0100001000xxxxxx'),
    ('CLRw', '0100001001xxxxxx'),
    ('CLRl', '0100001010xxxxxx'),
    ('NEGb', '0100010000xxxxxx'),
    ('NEGw', '0100010001xxxxxx'),
    ('NEGl', '0100010010xxxxxx'),
    ('NOTb', '0100011000xxxxxx'),
    ('NOTw', '0100011001xxxxxx'),
    ('NOTl', '0100011010xxxxxx'),
    ('TSTb', '0100101000xxxxxx'),
    ('TSTw', '0100101001xxxxxx'),
    ('TSTl', '0100101010xxxxxx'),
    ('CMPMb', '1011xxx100001xxx'),
    ('CMPMw', '1011xxx101001xxx'),
    ('CMPMl', '1011xxx110001xxx'),
    ('MOVEPw', '0000xxx1x0001xxx'),
    ('MOVEPl', '0000xxx1x1001xxx'),
    ('DBcc', '0101xxxx11001xxx'),
    ('SBCD', '1000xxx10000xxxx'),
    ('ABCD', '1100xxx10000xxxx'),
    ('EXGw', '1100xxx1000xxxx'),
    ('EXGl', '1100xxx1100xxxx'),
    ('SUBXb', '1001xxx10000xxxx'),
    ('SUBXw', '1001xxx10100xxxx'),
    ('SUBXl', '1001xxx11000xxxx'),
    ('ADDXb', '1101xxx10000xxxx'),
    ('ADDXw', '1101xxx10100xxxx'),
    ('ADDXl', '1101xxx11000xxxx'),
    ('NEGX', '01000000xxxxxxxx'),
    ('MOVEM', '01001x001xxxxxxx'),
    ('BRA', '01100000xxxxxxxx'),
    ('BSR', '01100001xxxxxxxx'),
    ('BTST', '0000xxx100xxxxxx'),
    ('BCHG', '0000xxx101xxxxxx'),
    ('BCLR', '0000xxx110xxxxxx'),
    ('BSET', '0000xxx111xxxxxx'),
    ('LEA', '0100xxx111xxxxxx'),
    ('CHK', '0100xxx110xxxxxx'),
    ('DIVU', '1000xxx011xxxxxx'),
    ('DIVS', '1000xxx111xxxxxx'),
    ('MULU', '1100xxx011xxxxxx'),
    ('MULS', '1100xxx111xxxxxx'),
    ('Scc', '0101xxxx11xxxxxx'),
    ('SUBAw', '1001xxx0x11xxxxx'),
    ('SUBAl', '1001xxx1x11xxxxx'),
    ('CMPAw', '1011xxx0x11xxxxx'),
    ('CMPAl', '1011xxx1x11xxxxx'),
    ('ADDAw', '1101xxx0x11xxxxx'),
    ('ADDAl', '1101xxx1x11xxxxx'),
    ('ASRb', '1110xxx000xx00xxx'),
    ('ASRw', '1110xxx001xx00xxx'),
    ('ASRl', '1110xxx010xx00xxx'),
    ('LSRb', '1110xxx000xx01xxx'),
    ('LSRw', '1110xxx001xx01xxx'),
    ('LSRl', '1110xxx010xx01xxx'),
    ('ROXRb', '1110xxx000xx10xxx'),
    ('ROXRw', '1110xxx001xx10xxx'),
    ('ROXRl', '1110xxx010xx10xxx'),
    ('RORb', '1110xxx000xx11xxx'),
    ('RORw', '1110xxx001xx11xxx'),
    ('RORl', '1110xxx010xx11xxx'),
    ('ASLb', '1110xxx100xx00xxx'),
    ('ASLw', '1110xxx101xx00xxx'),
    ('ASLl', '1110xxx110xx00xxx'),
    ('LSLb', '1110xxx100xx01xxx'),
    ('LSLw', '1110xxx101xx01xxx'),
    ('LSLl', '1110xxx110xx01xxx'),
    ('ROXLb', '1110xxx100xx10xxx'),
    ('ROXLw', '1110xxx101xx10xxx'),
    ('ROXLl', '1110xxx110xx10xxx'),
    ('ROLb', '1110xxx100xx11xxx'),
    ('ROLw', '1110xxx101xx11xxx'),
    ('ROLl', '1110xxx110xx11xxx'),
    ('ADDQb', '0101xxx000xxxxxx'),
    ('ADDQw', '0101xxx001xxxxxx'),
    ('ADDQl', '0101xxx010xxxxxx'),
    ('SUBQb', '0101xxx100xxxxxx'),
    ('SUBQw', '0101xxx101xxxxxx'),
    ('SUBQl', '0101xxx110xxxxxx'),
    ('EORb', '1011xxx100xxxxxx'),
    ('EORw', '1011xxx101xxxxxx'),
    ('EORl', '1011xxx110xxxxxx'),
    ('CMPb', '1011xxx000xxxxxx'),
    ('CMPw', '1011xxx001xxxxxx'),
    ('CMPl', '1011xxx010xxxxxx'),
    ('MOVEAw', '0001xxx001xxxxxx'),
    ('MOVEAl', '0011xxx001xxxxxx'),
    ('MOVEQ', '0111xxx0xxxxxxxx'),
    ('Bcc', '0110xxxxxxxxxxxx'),
    ('ORdnb', '1000xxx000xxxxxx'),
    ('ORdnw', '1000xxx001xxxxxx'),
    ('ORdnl', '1000xxx010xxxxxx'),
    ('OReab', '1000xxx100xxxxxx'),
    ('OReaw', '1000xxx101xxxxxx'),
    ('OReal', '1000xxx110xxxxxx'),
    ('SUBdnb', '1001xxx000xxxxxx'),
    ('SUBdnw', '1001xxx001xxxxxx'),
    ('SUBdnl', '1001xxx010xxxxxx'),
    ('SUBeab', '1001xxx100xxxxxx'),
    ('SUBeaw', '1001xxx101xxxxxx'),
    ('SUBeal', '1001xxx110xxxxxx'),
    ('ANDdnb', '1100xxx000xxxxxx'),
    ('ANDdnw', '1100xxx001xxxxxx'),
    ('ANDdnl', '1100xxx010xxxxxx'),
    ('ANDeab', '1100xxx100xxxxxx'),
    ('ANDeaw', '1100xxx101xxxxxx'),
    ('ANDeal', '1100xxx110xxxxxx'),
    ('ADDdnb', '1101xxx000xxxxxx'),
    ('ADDdnw', '1101xxx001xxxxxx'),
    ('ADDdnl', '1101xxx010xxxxxx'),
    ('ADDeab', '1101xxx100xxxxxx'),
    ('ADDeaw', '1101xxx101xxxxxx'),
    ('ADDeal', '1101xxx110xxxxxx'),
    ('MOVEb', '0001xxxxxxxxxxxx'),
    ('MOVEw', '0011xxxxxxxxxxxx'),
    ('MOVEl', '0010xxxxxxxxxxxx'),
]
#opcodes = [
#    ('ORItoCCR','0000000000111100'),
#    ('ORItoSR','0000000001111100'),
#    ('ANDItoCCR','0000001000111100'),
#    ('ANDItoSR','0000001001111100'),
#    ('EORItoCCR','0000101000111100'),
#    ('EORItoSR','0000101001111100'),
#    ('ILLEGAL','0100101011111100'),
#    ('RESET','0100111001110000'),
#    ('NOP','0100111001110001'),
#    ('STOP','0100111001110010'),
#    ('RTE','0100111001110011'),
#    ('RTS','0100111001110101'),
#    ('TRAPV','0100111001110110'),
#    ('RTR','0100111001110111'),
#    ('SWAP','0100100001000xxx'),
#    ('LINK','0100111001010xxx'),
#    ('UNLK','0100111001011xxx'),
#    ('EXT','010010001x000xxx'),
#    ('TRAP','010011100100xxxx'),
#    ('MOVEUSP','010011100110xxxx'),
#    ('BTST','0000100000xxxxxx'),
#    ('BCHG','0000100001xxxxxx'),
#    ('BCLR','0000100010xxxxxx'),
#    ('BSET','0000100011xxxxxx'),
#    ('MOVEfromSR','0100000011xxxxxx'),
#    ('MOVEtoCCR','0100010011xxxxxx'),
#    ('MOVEtoSR','0100011011xxxxxx'),
#    ('NBCD','0100100000xxxxxx'),
#    ('PEA','0100100001xxxxxx'),
#    ('TAS','0100101011xxxxxx'),
#    ('JSR','0100111010xxxxxx'),
#    ('JMP','0100111011xxxxxx'),
#    ('MOVEP','0000xxx1x1001xxx'),
#    ('DBcc','0101xxxx11001xxx'),
#    ('SBCD','1000xxx10000xxxx'),
#    ('ABCD','1100xxx10000xxxx'),
#    ('ASd','1110000x11xxxxxx'),
#    ('LSd','1110001x11xxxxxx'),
#    ('ROXd','1110010x11xxxxxx'),
#    ('ROd','1110011x11xxxxxx'),
#    ('ORI','00000000xxxxxxxx'),
#    ('ANDI','00000010xxxxxxxx'),
#    ('SUBI','00000100xxxxxxxx'),
#    ('ADDI','00000110xxxxxxxx'),
#    ('EORI','00001010xxxxxxxx'),
#    ('CMPI','00001100xxxxxxxx'),
#    ('NEGX','01000000xxxxxxxx'),
#    ('CLR','01000010xxxxxxxx'),
#    ('NEG','01000100xxxxxxxx'),
#    ('NOT','01000110xxxxxxxx'),
#    ('TST','01001010xxxxxxxx'),
#    ('MOVEM','01001x001xxxxxxx'),
#    ('BRA','01100000xxxxxxxx'),
#    ('BSR','01100001xxxxxxxx'),
#    ('CMPM','1011xxx1xx001xxx'),
#    ('EXG','1100xxx1x00xxxx'),
#    ('BTST','0000xxx100xxxxxx'),
#    ('BCHG','0000xxx101xxxxxx'),
#    ('BCLR','0000xxx110xxxxxx'),
#    ('BSET','0000xxx111xxxxxx'),
#    ('LEA','0100xxx111xxxxxx'),
#    ('CHK','0100xxx110xxxxxx'),
#    ('DIVU','1000xxx011xxxxxx'),
#    ('DIVS','1000xxx111xxxxxx'),
#    ('SUBX','1001xxx1xx00xxxx'),
#    ('MULU','1100xxx011xxxxxx'),
#    ('MULS','1100xxx111xxxxxx'),
#    ('ADDX','1101xxx1xx00xxxx'),
#    ('Scc','0101xxxx11xxxxxx'),
#    ('SUBA','1001xxxxx11xxxxx'),
#    ('CMPA','1011xxxxx11xxxxx'),
#    ('ADDA','1101xxxxx11xxxxx'),
#    ('ADDQ','0101xxx0xxxxxxxx'),
#    ('SUBQ','0101xxx1xxxxxxxx'),
#    ('MOVEQ','0111xxx0xxxxxxxx'),
#    ('EOR','1011xxx1xxxxxxxx'),
#    ('CMP','1011xxx0xxxxxxxx'),
#    ('ASd','1110xxxxxxxx00xxx'),
#    ('LSd','1110xxxxxxxx01xxx'),
#    ('ROXd','1110xxxxxxxx10xxx'),
#    ('ROd','1110xxxxxxxx11xxx'),
#    ('Bcc','0110xxxxxxxxxxxx'),
#    ('OR','1000xxxxxxxxxxxx'),
#    ('SUB','1001xxxxxxxxxxxx'),
#    ('AND','1100xxxxxxxxxxxx'),
#    ('ADD','1101xxxxxxxxxxxx'),
#    ('MOVEA','00xxxxxxxxxxxxxx'),
#    ('MOVE','00xxxxxxxxxxxxxx'),
#]

# Create 'matchers'
matchers = []
for mnemonic, encoding in opcodes:
    set_bits = 0
    any_bits = 0
    for bit in encoding:
        set_bits <<= 1
        any_bits <<= 1
        if bit == '1':
            set_bits |= 1
        if bit != 'x':
            any_bits |= 1
    matchers.append((mnemonic, set_bits, any_bits))

def match(word):
    for name, set_bits, any_bits in matchers:
        if (word & any_bits) ^ set_bits == 0:
            return name
    return None

luts = set()

# See how large the table would have to be
def check(prefix, lvl):
    matcher = None
    same = True
    entries = 0
    full_hash = 0
    if lvl < 4:
        for pattern in range(2 ** (16 - lvl * 4)):
            matched = match(prefix << (16 - lvl * 4) | pattern)
            if matcher != None and matcher != matched:
                same = False
                break
            matcher = matched
    else:
        matcher = match(prefix)
        full_hash = hash(matcher)
        same = True
    if lvl > 0:
        for _ in range(0, lvl-1):
            print('\t', end='')
        if same:
            print(f'{prefix:0{lvl}x}' + ('x' * (4 - lvl)) + f' {matcher}')
        else:
            print(f'{prefix:0{lvl}x}' + ('x' * (4 - lvl)))
    if not same:
        entries += 16
        sub_hashes = [0] * 16
        for i in range(0, 16):
            sub_ents, sub_hash = check((prefix << 4) + i, lvl + 1)
            sub_hashes[i] = sub_hash
            entries += sub_ents
        full_hash = hash(tuple(sub_hashes))
    elif lvl < 4:
        entries += (3 - lvl) * 16
        if matcher == None:
            full_hash = hash("None" * (4 - lvl))
        else:
            full_hash = hash(matcher * (4 - lvl))
    if full_hash in luts:
        return 0, full_hash
    else:
        luts.add(full_hash)
        return entries, full_hash
            
print(check(0, 0))
print(len(luts))

## Create lut masks
#MASK_SIZE = [7, 9]
#masks = [[0] * (2 ** size) for size in MASK_SIZE]
#for word in range(2 ** 16):
#    for idx, (m, set_bits, any_bits) in enumerate(matchers):
#        if (word & any_bits) ^ set_bits == 0:
#            masks[0][word >> (16 - MASK_SIZE[0])] |= 1 << idx
#            masks[1][word & ((2 ** MASK_SIZE[1]) - 1)] |= 1 << idx
#            break
#
## Print out the mask results
#for lut in masks:
#    print()
#    max_ones = 0
#    for byte, mask in enumerate(lut):
#        ones = bin(mask).count('1')
#        max_ones = max(max_ones, ones)
#        print(f'{byte:02x}: {mask:0{len(opcodes)}b} ({ones})')
#    print(f'max_ones: {max_ones}')
#        
## Test this factorized LUT against all possible inputs
#unmatched = 0
#highest_multi = 0
#for word in range(0, 2 ** 16):
#    matched_idx = None
#    mnemonic = ""
#    for idx, (m, set_bits, any_bits) in enumerate(matchers):
#        if (word & any_bits) ^ set_bits == 0:
#            matched_idx = idx
#            mnemonic = m
#            break
#    if matched_idx == None:
#        unmatched += 1
#        continue
#    
#    matches = masks[0][word >> (16 - MASK_SIZE[0])] & masks[1][word & ((2 ** MASK_SIZE[1]) - 1)]
#    
#    if bin(matches).count('1') == 0:
#        print(f'no matches for {mnemonic} ({word:04x})')
#    elif bin(matches).count('1') > 1:
#        print(f'too many matches for {mnemonic} ({word:04x})')
#        same = 0
#        for idx, bit in enumerate(bin(matches)[::-1]):
#            if bit != '1':
#                continue
#            same += 1
#            print(f'\tmatched for: {opcodes[idx][0]}')
#        highest_multi = max(highest_multi, same)
#    else:
#        factorized_idx = (matches & -matches).bit_length() - 1
#        if matched_idx != factorized_idx:
#            print(f'miss-match with word {mnemonic} ({word:04x})')
#
#print(f'n unmatched: {unmatched}')
#print(f'highest multi: {highest_multi}')

#LUT_POWER = 10
#buckets = [set() for _ in range(2 ** LUT_POWER)]
#for word in range(2 ** 16):
#    for mnemonic, set_bits, any_bits in matchers:
#        if (word & any_bits) ^ set_bits == 0:
#            buckets[word >> (16 - LUT_POWER)].add(mnemonic)
#            break
#
#for key, bucket in enumerate(buckets):
#    print(f'"{key:04x}"', end=', ')
#    for mnemonic in bucket:
#        print(f'"{mnemonic}"', end=', ')
#    print('')
