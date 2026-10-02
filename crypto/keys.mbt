///|
fn pem_der(text : String) -> Bytes raise CryptoError {
  @x509.pem(text) catch {
    e => raise Malformed("PEM: \{e}")
  }
}

///|
fn items(tlv : @asn1.Tlv) -> Array[@asn1.Tlv] raise CryptoError {
  tlv.items() catch {
    e => raise Malformed("DER structure: \{e}")
  }
}

///|
fn algorithm_oid(seq : @asn1.Tlv) -> String raise CryptoError {
  let fields = items(seq)
  if fields.is_empty() {
    raise Malformed("empty algorithm identifier")
  }
  fields[0].oid() catch {
    e => raise Malformed("algorithm OID: \{e}")
  }
}

///|
/// Load an RSA signing key from a PEM string: PKCS#8 (`BEGIN PRIVATE KEY`)
/// or PKCS#1 (`BEGIN RSA PRIVATE KEY`).
pub fn load_private_key_pem(text : String) -> @rsa.PrivateKey raise CryptoError {
  let der = pem_der(text)
  let top = @asn1.only(der[:]) catch {
    e => raise Malformed("private key DER: \{e}")
  }
  let fields = items(top)
  let rsa_seq = if fields.length() == 3 && fields[1].tag == 0x30 {
    let oid = algorithm_oid(fields[1])
    if oid != "1.2.840.113549.1.1.1" {
      raise Unsupported(
        "private key algorithm \{oid} (encrypted keys are not supported)",
      )
    }
    @asn1.only(fields[2].value) catch {
      e => raise Malformed("PKCS#8 RSAPrivateKey: \{e}")
    }
  } else if fields.length() == 9 && fields[1].tag == 0x02 {
    top
  } else {
    raise Malformed("private key: not a PKCS#8 or PKCS#1 RSA structure")
  }
  let rsa_fields = items(rsa_seq)
  if rsa_fields.length() != 9 {
    raise Malformed(
      "RSAPrivateKey: expected 9 fields, got \{rsa_fields.length()}",
    )
  }
  @rsa.PrivateKey::new(
    rsa_fields[1].value,
    rsa_fields[2].value,
    rsa_fields[3].value,
  ) catch {
    _ => raise Operation("RSAPrivateKey carries an unusable key")
  }
}

///|
/// Load an RSA public key from a SubjectPublicKeyInfo PEM string
/// (`BEGIN PUBLIC KEY`).
pub fn load_public_key_pem(text : String) -> @rsa.PublicKey raise CryptoError {
  let der = pem_der(text)
  public_key_from_spki_der(der)
}

///|
/// Build an RSA public key from DER SubjectPublicKeyInfo bytes.
pub fn public_key_from_spki_der(
  der : Bytes,
) -> @rsa.PublicKey raise CryptoError {
  let spki = @x509.Spki::read(der[:]) catch {
    e => raise Malformed("SubjectPublicKeyInfo: \{e}")
  }
  spki.rsa() catch {
    e => raise Unsupported("public key: \{e}")
  }
}
