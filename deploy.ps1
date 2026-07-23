New-Item `
 -Path "C:\Users\Public\Desktop\xxx.txt" `
 -ItemType File `
 -Force

"This is test file" |
 Out-File `
 "C:\Users\Public\Desktop\xxx.txt"