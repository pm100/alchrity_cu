from serial import Serial
serial_device = Serial("COM6", 115200, timeout=1)
bytes_out = "abcd".encode("ascii")
print (len(bytes_out))
#bytes_in = serial_device.read(len(bytes_out))
#print (bytes_in.decode("ascii"),len(bytes_in))

serial_device.write(bytes_out)
for i in range(0, len(bytes_out)):
    b = bytes_out[i:i+1]
    print ("sendiong ",b.decode("ascii"))

 #   serial_device.write(b)
    input()
    bytes_in = serial_device.read(1)
    print (bytes_in.decode("ascii"),len(bytes_in))
