with open("map.txt", "r") as f:
  for line in f.readlines():
    print("BYTE"),
    for c in line.strip():
      print("'" + c + "', "),
    print ""
