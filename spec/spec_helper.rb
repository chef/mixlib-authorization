require 'pp'
require 'rubygems'

gem "rest-client", ">= 1.0.3"

$:.unshift File.expand_path(File.dirname(__FILE__) + "/../lib/")
require "mixlib/authorization"
require 'mixlib/authorization/auth_helper'
require "mixlib/authorization/acl"
require 'mixlib/authorization/request_authentication'

require 'opscode/models/user'

RSpec.configure do |c|
  c.treat_symbols_as_metadata_keys_with_true_values = true

  # If you just want to run one (or a few) tests in development,
  # add :focus metadata
  c.filter_run :focus => true
  c.run_all_when_everything_filtered = true
end

Mixlib::Authorization::Config.authorization_service_uri ||= 'http://localhost:9463'

def mk_actor() 
  begin  
    uri = "#{Mixlib::Authorization::Config.authorization_service_uri}/actors"
    resp = RestClient.post uri, '{}', :content_type => 'application/json'
    actor =  JSON::parse(resp)["id"]
  rescue Exception => e
    puts "Can't create dummy actor id with uri #{uri}"
    exit
  end 
end

Mixlib::Authorization::Config.dummy_actor_id = mk_actor()
Mixlib::Authorization::Config.other_actor_id1 = mk_actor()
Mixlib::Authorization::Config.other_actor_id2 = mk_actor()

# Mixlib::Authorization::Config.dummy_actor_id = "5ca1ab1ef005ba111abe11eddecafbad"

puts "Using dummy_actor_id #{Mixlib::Authorization::Config.dummy_actor_id}"

Mixlib::Authorization::Config.superuser_id = "5ca1ab1ef005ba111abe11eddecafbad"

include Mixlib::Authorization

module AuthzFixtures
  CERT=(<<-C)
-----BEGIN CERTIFICATE-----
MIIDMjCCApugAwIBAgIEEA8lzzANBgkqhkiG9w0BAQUFADCBnjELMAkGA1UEBhMC
VVMxEzARBgNVBAgMCldhc2hpbmd0b24xEDAOBgNVBAcMB1NlYXR0bGUxFjAUBgNV
BAoMDU9wc2NvZGUsIEluYy4xHDAaBgNVBAsME0NlcnRpZmljYXRlIFNlcnZpY2Ux
MjAwBgNVBAMMKW9wc2NvZGUuY29tL2VtYWlsQWRkcmVzcz1hdXRoQG9wc2NvZGUu
Y29tMB4XDTExMDgwOTE3NDkzMloXDTExMDgwOTE3NDkzMlowgZcxEDAOBgNVBAcT
B1NlYXR0bGUxEzARBgNVBAgTCldhc2hpbmd0b24xCzAJBgNVBAYTAlVTMRwwGgYD
VQQLExNDZXJ0aWZpY2F0ZSBTZXJ2aWNlMRYwFAYDVQQKEw1PcHNjb2RlLCBJbmMu
MSswKQYDVQQDEyJVUkk6aHR0cDovL29wc2NvZGUuY29tL0dVSURTL2Z1dXV1MIIB
IjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA29kKiHivueJHC91s1dWG6lKG
HJQeKppDa5h/taa4xQRirgATooEZHrzl5jGFilbwZZ8QGUa1Rz21BcVP++n6DHft
jVbgxvfMZE7Bt+cA8pC0y5c3rFIWo4yyc1rQvsgTP+qqH/x90HJNf9qhHeNYnHM5
KqUT1YO/vhTMA0CxxQRTdKrs3ph36xQWcewtneu3Ntr2R7t+MdUeZGSXyNUqTCGK
aPZkndNauH3OsiBJyJlBxRakZ/u4d5SpSzykYAMpN0OyOTlEO6Al/YjiuAZK1b8d
v0Bf0p8DOMfl7V2s8J5+de1HOyb256l2qlxwK5jCyxAWCEM5sL7osYQ894n9wQID
AQABMA0GCSqGSIb3DQEBBQUAA4GBAAuRGZKJmt0ZYlmtGiF/ggTtxQUMdtpd1qkM
k9SdI9/an2TZqnBoZ37oAZk/HNySFURYftyDAI6i9JSz31S0Lzj2y698tJK8c1Is
ZxrUk2TCC2CA1pmnRM8brAntFYy4uodowSmj6n8ItR8zYhN2DchCZAvkvuCzuF1M
4tbi+5la
-----END CERTIFICATE-----
C

  PRIVKEY=(<<-K)
-----BEGIN RSA PRIVATE KEY-----
MIIEpQIBAAKCAQEA29kKiHivueJHC91s1dWG6lKGHJQeKppDa5h/taa4xQRirgAT
ooEZHrzl5jGFilbwZZ8QGUa1Rz21BcVP++n6DHftjVbgxvfMZE7Bt+cA8pC0y5c3
rFIWo4yyc1rQvsgTP+qqH/x90HJNf9qhHeNYnHM5KqUT1YO/vhTMA0CxxQRTdKrs
3ph36xQWcewtneu3Ntr2R7t+MdUeZGSXyNUqTCGKaPZkndNauH3OsiBJyJlBxRak
Z/u4d5SpSzykYAMpN0OyOTlEO6Al/YjiuAZK1b8dv0Bf0p8DOMfl7V2s8J5+de1H
Oyb256l2qlxwK5jCyxAWCEM5sL7osYQ894n9wQIDAQABAoIBAAUb5x3CyDqmooYJ
EEVr3+XEIy+41Xah/R0b/yPGixaxAmYOxGYLX/0R4LnXvsW3PYDvEF22AfJ04acP
rcsp5dCyXMfjE/grvAk8t03BxYjdigYNLpMHmVUVqPP7UUyNs7zRhECYCoh0j46A
EyxxoxaHqvVtvqdAl40gSJluwHLWmt09wcrrDI4g+Xb19oS6HgTJZTzLsQhSFk47
LSiqlSIDCGxW8dAGt5/YLx21XeVUqUCzexHUYmanwZyI3CIINWfOPFsl8XJRFcnW
KpSr7Rh9c86xeoeY80MN3HedhTPYZj891RI2dXkrDyo0u83zIwaGvhxxhhv/dCDX
6qSqqQECgYEA9h/O5i/1+HdWeGMbckh7/PGyFfG50x1Z3ibJO6ooPr9A4ND0ObO7
eYjZpfa61YGp9a1hXTZNxvWOVt/f7uiMIK04AMBJdFPx3XSuru2dymEpEKPGc+7J
IJ3XZukis44I4YRY8PNuJIQn3YyAtgV7gaZjoPz5B6IhvqzLYq03IvECgYEA5KtS
L+ssa2tqUD5QEBpUijZ3XrT9KKQCdSKhroKQYPHfE5hzbyngzhj7PGqh3WI9XFYd
MiF3cZXVMe3jZ33LgjvGv90RVHvYn8k89/plg+pTGgaVyWs8G2subvfLObOrngM3
KbqbH2+v701GzFsSgDu9qcr5FWTqzNjX3g7v59ECgYEAszKNjYM172XUC2r9PMQR
oiTHqLqKtW8VU22h7lMBYk4VipoYdzqpMN+2t+NgPLtfZ4SI8zjqgAWhURdHD8c4
30G/GKznzk6gNsERvkM7M3JyV68meppMzfaeMktj/J9ZT/jwWN6kPuoJrIDz5ZMw
TUE8IKaPGkOtlgpxOrMrBcECgYEAoSaDkzWfZkya7dYcQlzr+0OLOHlAeCWtfbNc
Ukm9SjTqyzqDD3Jp9ZTxaZCUZhpXt/0QMkYXkTrQtpE507N5elx6Iri+/9UPwvvl
NbWHWUIIMq01Xm9uOrx8SsPiutV+Oqt1crkJnUvupyzEmjwMe8aeUUyz4XnvZ1Hi
P6IzPCECgYEAoULgvdhfOXPNg0gmvUybOZajWRn5081EkX105opnzbCJ4xOPnWne
cwIYoWlPr/BBzX7+ikWRL2UJCbi8qlrbeZ6hS16jgMOOkDnqtdVj3EkGnswwg90j
CiNjEbSCxT49UbPN3ogFoXe5Eh/HE88mWMPTCfZNM7gI6sp8lmG2yZ8=
-----END RSA PRIVATE KEY-----
K

  WRONG_CERT=(<<-W)
-----BEGIN CERTIFICATE-----
MIIDMTCCApqgAwIBAgIEEA8lzzANBgkqhkiG9w0BAQUFADCBnjELMAkGA1UEBhMC
VVMxEzARBgNVBAgMCldhc2hpbmd0b24xEDAOBgNVBAcMB1NlYXR0bGUxFjAUBgNV
BAoMDU9wc2NvZGUsIEluYy4xHDAaBgNVBAsME0NlcnRpZmljYXRlIFNlcnZpY2Ux
MjAwBgNVBAMMKW9wc2NvZGUuY29tL2VtYWlsQWRkcmVzcz1hdXRoQG9wc2NvZGUu
Y29tMB4XDTExMDgwOTE5MTkwNloXDTExMDgwOTE5MTkwNlowgZYxEDAOBgNVBAcT
B1NlYXR0bGUxEzARBgNVBAgTCldhc2hpbmd0b24xCzAJBgNVBAYTAlVTMRwwGgYD
VQQLExNDZXJ0aWZpY2F0ZSBTZXJ2aWNlMRYwFAYDVQQKEw1PcHNjb2RlLCBJbmMu
MSowKAYDVQQDEyFVUkk6aHR0cDovL29wc2NvZGUuY29tL0dVSURTL2Z1dTIwggEi
MA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDTf17mCZmFj5lINPs+agfIG9xl
WEF2h524BYI1+39JTy/KDQso4fMry5U5GZ1kaMhbP9q9P49q5/NCJGvK0FNObTav
pYnL8XyGxvJoibamKI7DgKnshLcynvYVaa4dQtA1MFr2e7BrfRsCQj8Q53IDeWnh
73BUol87G1sXk1Oir0Kd6HOirNxdcKIUcYe3jJou246r+LyFgK3oXbN4s6bqVgca
GKZIEWVCVpGTGMtEDFkjsTdWzoUgwKilNrdNZPbwyJ3rmWx2vAmsrgQZxhZqI4XX
0Auco2iG5jAVlB00/Ch7mXof23J/7Jt3KYSa5cZqldPMcgthD77fcvMN9cgDAgMB
AAEwDQYJKoZIhvcNAQEFBQADgYEAglAaZ8TegdKcTmIlIa8BehpqZ/3tfHQfaMcd
EwXB7Cz3wN2Z2brrhT5TncgUnqIqnCMbsEi4ZGkZC0zeS/pccH3RXRPAbDCK6BoF
bjHSE71XlAzwvoWGDtjrn9Kqp3trrKouIN+kh70P8iPLMu4lWUkUryt/CjS2Wb5o
MGoUm4A=
-----END CERTIFICATE-----
W

  PUBKEY2=OpenSSL::PKey::RSA.new(<<-K).to_s
-----BEGIN RSA PUBLIC KEY-----
MIIBCgKCAQEA1BNQtuo/KvQ+mRlEFRT8cVd+eO7ltKE0plg1IKYTeC3YK8SMuy1T
QYXvzgQifENlkK5t9ojSBrlvy2MNwTcNRwni2hUHhVMo0B8tbY5BZ4V+t7pho57a
y8bBj3170RGpBxULZmDm5vs8SWAF+aVvTfgcd9mtzuBFt710k74AtkTGGsE0n6ES
ljFPse84dDE/KTYQuabH2v9ZpGTT36HuFjNg7scxzkTsARBzyWQXbc/1t/rlHbjc
GR7BI9qJS3ZSk3qVSNjdE5Wem9EnK2Nn5Nj94fgBMbeQRkG/0x8amrX8sP1wPGua
pG2EoptKrViTHy58ieaVI/CLJBzvV4aFHQIDAQAB
-----END RSA PUBLIC KEY-----
K

  PRIVKEY2=(<<-K)
-----BEGIN RSA PRIVATE KEY-----
MIIEpQIBAAKCAQEA1BNQtuo/KvQ+mRlEFRT8cVd+eO7ltKE0plg1IKYTeC3YK8SM
uy1TQYXvzgQifENlkK5t9ojSBrlvy2MNwTcNRwni2hUHhVMo0B8tbY5BZ4V+t7ph
o57ay8bBj3170RGpBxULZmDm5vs8SWAF+aVvTfgcd9mtzuBFt710k74AtkTGGsE0
n6ESljFPse84dDE/KTYQuabH2v9ZpGTT36HuFjNg7scxzkTsARBzyWQXbc/1t/rl
HbjcGR7BI9qJS3ZSk3qVSNjdE5Wem9EnK2Nn5Nj94fgBMbeQRkG/0x8amrX8sP1w
PGuapG2EoptKrViTHy58ieaVI/CLJBzvV4aFHQIDAQABAoIBAEobWcghQOOMp9ct
6gmH5NLiZRJzQJeHAXPjPOVkw0bqljBtJVQ++WnbGLof3cEYeAQ/v7M3ilTJNdSX
j3Xl++DIBpp4YMFpFsjrLB+tZxN6pZYkLfxUBVbR5E905PBgwHT2GJ6029r5Dc8C
G/Rpp+RR//itezvgSNx0+qip62vFJ489Tz99AbQak8fFs4UxI0vd82GSKK4T9ffL
+mPvxY6XUDlH8e5mNhrWB1LoaBxSpNehVhNzGtaFdVuQEkxqaR+eODN6GWK3YA9M
EfvIGc4A0/UVxqcxfZ09RCrGWS+mU+yd+Ln6oIRSjhLagmA+i/sMFs7SvasPjaCo
mSDOWu0CgYEA8owL1hIYaboOG7RxEW+oFBCzEuOWPtXQ4c8SPKh0uR1dK2FgLqWv
EGYvfQT7RITd5Xkjo4ac4xV4LCsroif+OcPwvr8cOPfirhmzg1i1Apj0sjD7+cue
KttlrJKeYF0TRLi67ljPv7nSd3/QhgTmjqt9/m8Jbq8IDXA8jwWsVx8CgYEA39aZ
ZSlh4QrFcyrfUCfuUU3RxnOqOfDGA+RemwRm3EFGdIDY1HkaVyN9h2g+zbFNLZBR
vi14TeiKFtI8QdjYKMuzSkXhNSbnDm/ZPDjJAVkNlBiF8Q2haz6VL/3W4YtpBQvm
1AeWr2NBRZ3WyzNAFI22Wg4aXqGQYpp8yfa1SEMCgYEAhCrMSFqT8wjvpyksc9Pk
QwrWifR6asMYj/PGfEdPU5AstPba8pBWVRlZx0ZvpWbBg8n/IZy44QVR9r+Ph01D
uzaKeWaqemCZpUVcDLbJ7CBtNqx6oiPSjIgBX4iFxPzzAv+m3TqH+nHHvlZnyp/h
At1wSrU27plySeBfH5B32QECgYEAoTBOglTMkVxKV+b1rSk0KwRZHgnI+bRzQ/Y+
Um9XCyFOdTMb8dXLrBh4mvvszf7xzu/wjXz8902Ps2Nt1RUshCQ8Vi4AQWBkXzcY
Po+93+SbLJyER9RC+5GzqT2ocf8Mf3/Ul7dnQaG+LT2+odGkQajTOgKR5rd93CPX
3TB11zUCgYEA6kvQk65Xe4BjpaKLLXAiS9tSBLw5aJnW7FhVrQETiiri/y2/Uia1
Oho2Vx6Hs3VCDu5ZeqE848WfCtFRkDnZajRFvPQv2Kpma0JVXahFxdrLTGNWfYfD
5smF/nASV9vaCF45S+ZL3plXhlnCw+s/IZy/XQj4vTia0xuADbM8FXw=
-----END RSA PRIVATE KEY-----
K

PUBKEY3=OpenSSL::PKey::RSA.new(<<-K).to_s
-----BEGIN RSA PUBLIC KEY-----
MIICCgKCAgEAtNMqfAqdWzBD0dIkF45oFhl5NXZRF9UXrQNAIlIJvpQXwCYKmdVw
LLWYJ0fnC2RNRAqcA7CO1nENc4vGTk5V4mqJsO1TSK2AvrfezyEGXYkav6BMjBSm
oU7lddUE+OrOfbIs9LPygrHzhlxD/5iFStoaAkn0hz/I5d6x1RZjoa15YXuijoau
tTdhIhRb7uCAO3U8kjIRd2m0Bc876duUhyJFYfA7ALqFeYvOAGRkQ2y9bkC85iqf
8K2Q6pqcbnBVxpT1XiWKIuT6S3GkqpLFEQF9yXv38A13wAhyqSDWUwAeEEnMNq24
7UorWWXvKzK/xW4arIcCpEHSb2SghHA5Swk4jxhliOsyzVV2QYt+PZf7IEI23fsH
EcnjhoGm2MffzfbxpohMNdL0FGeuOadI8jwHBqVhzTxAi+fPiAvNEj0ogEUk6SXL
ETS27CiwFMXFwkj7MG7c6SZGGpo/zb/zB/X/pTqHVYoudt9U9k/WWzn9LrPSPaWx
OddM42EnG2j0X+tC0R0ydW/CGXR33vfcnX9/F8W8MIuFQ+8WeNdtRX25nzjuhxAS
82LOBJ+2xUbMOpVYiP/n1rYBe5kP16NHmCLTIZzg8ljJOCTqWo5uQWycwGYn8UWt
GTCY8vadAwmHAyOE8YIoLMxGWp/naJeT2FoAlkBqg3GRWbHeSv0MyXsCAwEAAQ==
-----END RSA PUBLIC KEY-----
K

end
