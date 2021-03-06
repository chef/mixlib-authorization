module Fixtures

  SAMPLE_CERT =<<-CERT
-----BEGIN CERTIFICATE-----
MIIDODCCAqGgAwIBAgIEz5HZWDANBgkqhkiG9w0BAQUFADCBnjELMAkGA1UEBhMC
VVMxEzARBgNVBAgMCldhc2hpbmd0b24xEDAOBgNVBAcMB1NlYXR0bGUxFjAUBgNV
BAoMDU9wc2NvZGUsIEluYy4xHDAaBgNVBAsME0NlcnRpZmljYXRlIFNlcnZpY2Ux
MjAwBgNVBAMMKW9wc2NvZGUuY29tL2VtYWlsQWRkcmVzcz1hdXRoQG9wc2NvZGUu
Y29tMCAXDTExMDcxOTIyNTY1MloYDzIxMDAwOTIwMjI1NjUyWjCBmzEQMA4GA1UE
BxMHU2VhdHRsZTETMBEGA1UECBMKV2FzaGluZ3RvbjELMAkGA1UEBhMCVVMxHDAa
BgNVBAsTE0NlcnRpZmljYXRlIFNlcnZpY2UxFjAUBgNVBAoTDU9wc2NvZGUsIElu
Yy4xLzAtBgNVBAMUJlVSSTpodHRwOi8vb3BzY29kZS5jb20vR1VJRFMvdXNlcl9n
dWlkMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0NKi934E1BoX2PVP
Nlv+2rtdFervrNt5tK762QYFBlciwAdH0DIxcBsEpJyi/V/IAPi05LRoIs+a2qjN
VD73YjxoKIVnm3wFOEHY6XKMN0NCzyhPPxGQqws9aSSOU1lGa72sOoPGH+1e46ni
7adW1TMTNN8w8bYCXeL2dvyXAbzlTap+tLbkeKgjt9MvRwFQfQ8Im9KqfuHDbVJn
EquRIx/0TbT+BF9jBg463GG0tMKySulqw4+CpAAh2BxdjvdcfIpXQNPJao3CgvGF
xN+GlrHO5kIGNT0iie+Z02TUr8sIAhc6n21q/F06W7i7vY07WgiwT+iLJ+IG4ylQ
ewAYtwIDAQABMA0GCSqGSIb3DQEBBQUAA4GBAGKC0q99xFwyrHZkKhrMOZSWLV/L
9t4WWPdI+iGB6bG0sbUF+bWRIetPtUY5Ueqf7zLxkFBvFkC/ob4Kb5/S+81/jE0r
h7zcu9piePUXRq+wzg6be6mTL/+YVFtowSeBR1sZbhjtNM8vv2fVq7OEkb7BYJ9l
HYCz2siW4sVv9rca
-----END CERTIFICATE-----
CERT

  SAMPLE_CERT_KEY = OpenSSL::PKey::RSA.new(<<-KEY).to_s
-----BEGIN RSA PUBLIC KEY-----
MIIBCgKCAQEA0NKi934E1BoX2PVPNlv+2rtdFervrNt5tK762QYFBlciwAdH0DIx
cBsEpJyi/V/IAPi05LRoIs+a2qjNVD73YjxoKIVnm3wFOEHY6XKMN0NCzyhPPxGQ
qws9aSSOU1lGa72sOoPGH+1e46ni7adW1TMTNN8w8bYCXeL2dvyXAbzlTap+tLbk
eKgjt9MvRwFQfQ8Im9KqfuHDbVJnEquRIx/0TbT+BF9jBg463GG0tMKySulqw4+C
pAAh2BxdjvdcfIpXQNPJao3CgvGFxN+GlrHO5kIGNT0iie+Z02TUr8sIAhc6n21q
/F06W7i7vY07WgiwT+iLJ+IG4ylQewAYtwIDAQAB
-----END RSA PUBLIC KEY-----
KEY

  ALTERNATE_CERT =<<-COOLSTORYBRO
-----BEGIN CERTIFICATE-----
MIIDOzCCAqSgAwIBAgIEexe5WDANBgkqhkiG9w0BAQUFADCBnjELMAkGA1UEBhMC
VVMxEzARBgNVBAgMCldhc2hpbmd0b24xEDAOBgNVBAcMB1NlYXR0bGUxFjAUBgNV
BAoMDU9wc2NvZGUsIEluYy4xHDAaBgNVBAsME0NlcnRpZmljYXRlIFNlcnZpY2Ux
MjAwBgNVBAMMKW9wc2NvZGUuY29tL2VtYWlsQWRkcmVzcz1hdXRoQG9wc2NvZGUu
Y29tMCAXDTExMDcyODIzMDIwM1oYDzIxMDAxMjA2MjMwMjAzWjCBnjEQMA4GA1UE
BxMHU2VhdHRsZTETMBEGA1UECBMKV2FzaGluZ3RvbjELMAkGA1UEBhMCVVMxHDAa
BgNVBAsTE0NlcnRpZmljYXRlIFNlcnZpY2UxFjAUBgNVBAoTDU9wc2NvZGUsIElu
Yy4xMjAwBgNVBAMTKVVSSTpodHRwOi8vb3BzY29kZS5jb20vR1VJRFMvY29vbHN0
b3J5YnJvMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA73l5DmlZVl9E
A1J54x/Xb7WGVrjH+RNN9ZVd082EdckOVCW8l/X0CDyda4nykBixPN8L8R4SIVfb
ZltMw97a9cjEHXYLJd+w7sInS1g9ESv3mkS2TyUyhssVzPLeeFR0KUwrhFG48dlL
r6ELggodZAE8QGaCBM8Le/al413H8yBcc7WAq6HCP/QYKpMMMGkppYIMBuVPsxnC
+G5G7z3xg4pg+cV/omObpmNd/J2pQJpwhgB2eZ0J5vZ/yITdHuE8ta/zjQH0NIu7
BDG4yApXeO7ASKcJeO6eXAVNkkvK3L72Ir1d670kjlk0nxpdo1LLa6h1wTdnGDLP
VpN65qTHpQIDAQABMA0GCSqGSIb3DQEBBQUAA4GBAC8Zba1PnApAkqaFfmB/g1xr
9/QRKl85qkcZMh68yxzP9ieLherM0PbVBdvlUvHkzrVW1/x1WG8tX4+BdXt1LCPA
Azn+L+rRNETN573yx+Y+FRxebWqaZ7iSIJxQ1dVT2oAt0+4/NC7csHRdmjn8rnXn
2oe/3dZFrPoZCLXhQb1w
-----END CERTIFICATE-----
COOLSTORYBRO

end

