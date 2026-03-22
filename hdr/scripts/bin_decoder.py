
def decode_uart(bits_string):
    return hex(int(bits_string[::-1], 2))

while(True):
    binary=input("Enter Binary: ")
    print(decode_uart(binary))