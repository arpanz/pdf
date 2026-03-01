use aes::Aes256;
use block_modes::{BlockCipher, Cbc};
use lopdf::{Document, Object};
use rand::Rng;
use sha2::{Digest, Sha256};
use std::path::PathBuf;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum SecurityError {
    #[error("Failed to open PDF: {0}")]
    OpenError(String),
    #[error("Failed to encrypt PDF: {0}")]
    EncryptError(String),
    #[error("Failed to decrypt PDF: {0}")]
    DecryptError(String),
    #[error("Failed to save PDF: {0}")]
    SaveError(String),
    #[error("Invalid password")]
    InvalidPassword,
    #[error("File not found: {0}")]
    FileNotFound(String),
    #[error("PDF is not encrypted")]
    NotEncrypted,
    #[error("PDF is already encrypted")]
    AlreadyEncrypted,
}

type Aes256Cbc = Cbc<Aes256, block_modes::padding::Pkcs7>;

/// Derive a 256-bit key from password using SHA-256
fn derive_key(password: &str) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(password.as_bytes());
    let result = hasher.finalize();
    let mut key = [0u8; 32];
    key.copy_from_slice(&result);
    key
}

/// Derive a 128-bit IV from password
fn derive_iv(password: &str) -> [u8; 16] {
    let mut hasher = Sha256::new();
    hasher.update(password.as_bytes());
    hasher.update(b"iv");
    let result = hasher.finalize();
    let mut iv = [0u8; 16];
    iv.copy_from_slice(&result[..16]);
    iv
}

/// Encrypt a PDF with a password
pub fn encrypt_pdf(input_path: String, password: String, output_path: String) -> Result<String, SecurityError> {
    let path_buf = PathBuf::from(&input_path);
    if !path_buf.exists() {
        return Err(SecurityError::FileNotFound(input_path));
    }

    let mut doc = Document::load(&input_path)
        .map_err(|e| SecurityError::OpenError(e.to_string()))?;

    // Check if already encrypted
    if doc.encryption.is_some() {
        return Err(SecurityError::AlreadyEncrypted);
    }

    // Generate random owner password hash
    let mut rng = rand::thread_rng();
    let owner_pass_hash: Vec<u8> = (0..32).map(|_| rng.gen()).collect();
    
    // Derive user password
    let user_key = derive_key(&password);
    let user_pass_hash = {
        let mut hasher = Sha256::new();
        hasher.update(&user_key);
        hasher.finalize().to_vec()
    };

    // Create encryption dictionary
    let encryption_dict_id = doc.new_object_id();
    
    // Create the encryption dictionary
    let mut encryption_dict = lopdf::Dictionary::new();
    encryption_dict.set("Filter", Object::Name(b"Standard".to_vec()));
    encryption_dict.set("V", Object::Integer(4));
    encryption_dict.set("Length", Object::Integer(256));
    encryption_dict.set("R", Object::Integer(5));
    encryption_dict.set("U", Object::String(user_pass_hash.clone(), lopdf::StringFormat::Literal));
    encryption_dict.set("O", Object::String(owner_pass_hash, lopdf::StringFormat::Literal));
    encryption_dict.set("P", Object::Integer(-3904)); // Default permissions
    
    // Set up encryption key
    let mut encryption_key = derive_key(&password);
    // Extend to 32 bytes if needed
    while encryption_key.len() < 32 {
        encryption_key.push(0);
    }
    let key: [u8; 32] = encryption_key[..32].try_into().unwrap_or_else(|_| {
        let mut k = [0u8; 32];
        k.copy_from_slice(&encryption_key);
        k
    });

    // Encrypt the document
    doc.encrypt(&key[..16], &user_pass_hash, &owner_pass_hash)
        .map_err(|e| SecurityError::EncryptError(e.to_string()))?;

    // Save the encrypted PDF
    doc.save(&output_path)
        .map_err(|e| SecurityError::SaveError(e.to_string()))?;

    Ok(output_path)
}

/// Decrypt a PDF with a password
pub fn decrypt_pdf(input_path: String, password: String, output_path: String) -> Result<String, SecurityError> {
    let path_buf = PathBuf::from(&input_path);
    if !path_buf.exists() {
        return Err(SecurityError::FileNotFound(input_path));
    }

    let mut doc = Document::load(&input_path)
        .map_err(|e| SecurityError::OpenError(e.to_string()))?;

    // Check if encrypted
    if doc.encryption.is_none() {
        return Err(SecurityError::NotEncrypted);
    }

    // Try to decrypt with the password
    let user_key = derive_key(&password);
    let user_pass_hash = {
        let mut hasher = Sha256::new();
        hasher.update(&user_key);
        hasher.finalize().to_vec()
    };

    // Remove encryption
    doc.decrypt(&user_key[..16])
        .map_err(|_| SecurityError::InvalidPassword)?;

    // Remove encryption dictionary
    doc.encryption = None;

    // Save the decrypted PDF
    doc.save(&output_path)
        .map_err(|e| SecurityError::SaveError(e.to_string()))?;

    Ok(output_path)
}

/// Check if a PDF is encrypted
pub fn is_encrypted(path: String) -> Result<bool, SecurityError> {
    let path_buf = PathBuf::from(&path);
    if !path_buf.exists() {
        return Err(SecurityError::FileNotFound(path));
    }

    let doc = Document::load(&path)
        .map_err(|e| SecurityError::OpenError(e.to_string()))?;

    Ok(doc.encryption.is_some())
}

/// Get PDF encryption info
pub fn get_encryption_info(path: String) -> Result<EncryptionInfo, SecurityError> {
    let path_buf = PathBuf::from(&path);
    if !path_buf.exists() {
        return Err(SecurityError::FileNotFound(path));
    }

    let doc = Document::load(&path)
        .map_err(|e| SecurityError::OpenError(e.to_string()))?;

    let is_encrypted = doc.encryption.is_some();
    let page_count = doc.get_pages().len() as i32;

    Ok(EncryptionInfo {
        is_encrypted,
        page_count,
    })
}

#[derive(Debug, Clone)]
pub struct EncryptionInfo {
    pub is_encrypted: bool,
    pub page_count: i32,
}
