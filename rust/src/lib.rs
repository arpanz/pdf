mod api;

use api::merge::{PdfProcessor, PdfError};
use api::security::{encrypt_pdf, decrypt_pdf, is_encrypted, get_encryption_info, SecurityError, EncryptionInfo};
use api::compress::{compress_pdf, get_compression_info, CompressError, CompressionInfo};
use api::split::{extract_pages, split_to_single_pages, get_pages, SplitError};
use flutter_rust_bridge::frb;
use std::path::PathBuf;

// ============== API STRUCTURES ==============

#[derive(Debug, Clone)]
pub struct PdfResult {
    pub success: bool,
    pub output_path: String,
    pub error: Option<String>,
}

#[derive(Debug, Clone)]
pub struct PageInfo {
    pub page_number: i32,
    pub width: Option<f64>,
    pub height: Option<f64>,
}

#[derive(Debug, Clone)]
pub struct FileInfo {
    pub path: String,
    pub size_bytes: u64,
    pub page_count: i32,
    pub is_encrypted: bool,
}

// ============== MERGE OPERATIONS ==============

#[frb(sync)]
pub fn merge_pdfs(paths: Vec<String>, output_path: String) -> PdfResult {
    match PdfProcessor::merge_pdfs(paths, output_path) {
        Ok(path) => PdfResult {
            success: true,
            output_path: path,
            error: None,
        },
        Err(e) => PdfResult {
            success: false,
            output_path: String::new(),
            error: Some(e.to_string()),
        },
    }
}

#[frb(sync)]
pub fn split_pdf(input_path: String, pages: Vec<i32>, output_path: String) -> PdfResult {
    match PdfProcessor::split_pdf(input_path, pages, output_path) {
        Ok(path) => PdfResult {
            success: true,
            output_path: path,
            error: None,
        },
        Err(e) => PdfResult {
            success: false,
            output_path: String::new(),
            error: Some(e.to_string()),
        },
    }
}

#[frb(sync)]
pub fn extract_pdf_pages(input_path: String, pages: Vec<i32>, output_path: String) -> PdfResult {
    match extract_pages(input_path, pages, output_path) {
        Ok(path) => PdfResult {
            success: true,
            output_path: path,
            error: None,
        },
        Err(e) => PdfResult {
            success: false,
            output_path: String::new(),
            error: Some(e.to_string()),
        },
    }
}

#[frb(sync)]
pub fn split_pdf_to_single_pages(input_path: String, output_dir: String) -> Result<Vec<String>, String> {
    split_to_single_pages(input_path, output_dir)
        .map_err(|e| e.to_string())
}

// ============== SECURITY OPERATIONS ==============

#[frb(sync)]
pub fn protect_pdf(input_path: String, password: String, output_path: String) -> PdfResult {
    match encrypt_pdf(input_path, password, output_path) {
        Ok(path) => PdfResult {
            success: true,
            output_path: path,
            error: None,
        },
        Err(e) => PdfResult {
            success: false,
            output_path: String::new(),
            error: Some(e.to_string()),
        },
    }
}

#[frb(sync)]
pub fn unlock_pdf(input_path: String, password: String, output_path: String) -> PdfResult {
    match decrypt_pdf(input_path, password, output_path) {
        Ok(path) => PdfResult {
            success: true,
            output_path: path,
            error: None,
        },
        Err(e) => PdfResult {
            success: false,
            output_path: String::new(),
            error: Some(e.to_string()),
        },
    }
}

#[frb(sync)]
pub fn check_pdf_encrypted(path: String) -> Result<bool, String> {
    is_encrypted(path).map_err(|e| e.to_string())
}

#[frb(sync)]
pub fn get_pdf_encryption_info(path: String) -> Result<EncryptionInfo, String> {
    get_encryption_info(path).map_err(|e| e.to_string())
}

// ============== COMPRESSION OPERATIONS ==============

#[frb(sync)]
pub fn compress_pdf_file(input_path: String, level: i32, output_path: String) -> PdfResult {
    match compress_pdf(input_path, level, output_path) {
        Ok(path) => PdfResult {
            success: true,
            output_path: path,
            error: None,
        },
        Err(e) => PdfResult {
            success: false,
            output_path: String::new(),
            error: Some(e.to_string()),
        },
    }
}

#[frb(sync)]
pub fn get_pdf_compression_info(path: String) -> Result<CompressionInfo, String> {
    get_compression_info(path).map_err(|e| e.to_string())
}

// ============== UTILITY OPERATIONS ==============

#[frb(sync)]
pub fn get_pdf_page_count(path: String) -> Result<i32, String> {
    PdfProcessor::get_page_count(path).map_err(|e| e.to_string())
}

#[frb(sync)]
pub fn get_pdf_file_size(path: String) -> Result<u64, String> {
    PdfProcessor::get_file_size(path).map_err(|e| e.to_string())
}

#[frb(sync)]
pub fn get_pdf_pages(path: String) -> Result<Vec<i32>, String> {
    get_pages(path).map_err(|e| e.to_string())
}

#[frb(sync)]
pub fn get_app_documents_dir() -> Result<String, String> {
    dirs::document_dir()
        .map(|p| p.to_string_lossy().to_string())
        .ok_or_else(|| "Could not find documents directory".to_string())
}

#[frb(sync)]
pub fn get_output_directory() -> Result<String, String> {
    let docs_dir = dirs::document_dir()
        .ok_or_else(|| "Could not find documents directory".to_string())?;
    
    let output_dir = docs_dir.join("BatchPDF");
    
    // Create directory if it doesn't exist
    if !output_dir.exists() {
        std::fs::create_dir_all(&output_dir)
            .map_err(|e| e.to_string())?;
    }
    
    Ok(output_dir.to_string_lossy().to_string())
}

#[frb(sync)]
pub fn generate_output_filename(prefix: String, extension: String) -> String {
    let timestamp = chrono::Local::now().format("%Y%m%d_%H%M%S");
    let uuid = uuid::Uuid::new_v4().to_string()[..8].to_string();
    format!("{}_{}_{}.{}", prefix, timestamp, uuid, extension)
}

// ============== FILE OPERATIONS ==============

#[frb(sync)]
pub fn copy_file(source: String, destination: String) -> Result<String, String> {
    std::fs::copy(&source, &destination)
        .map_err(|e| e.to_string())?;
    Ok(destination)
}

#[frb(sync)]
pub fn delete_file(path: String) -> Result<bool, String> {
    std::fs::remove_file(&path).map_err(|e| e.to_string())?;
    Ok(true)
}

#[frb(sync)]
pub fn file_exists(path: String) -> bool {
    PathBuf::from(&path).exists()
}
