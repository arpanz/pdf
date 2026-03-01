use lopdf::{Document, Object, ObjectId};
use std::collections::BTreeMap;
use std::path::PathBuf;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum SplitError {
    #[error("Failed to open PDF: {0}")]
    OpenError(String),
    #[error("Failed to split PDF: {0}")]
    SplitError(String),
    #[error("Failed to save PDF: {0}")]
    SaveError(String),
    #[error("Invalid page range: {0}")]
    InvalidPageRange(String),
    #[error("File not found: {0}")]
    FileNotFound(String),
}

/// Extract specific pages from a PDF into a new PDF
pub fn extract_pages(input_path: String, pages: Vec<i32>, output_path: String) -> Result<String, SplitError> {
    let path_buf = PathBuf::from(&input_path);
    if !path_buf.exists() {
        return Err(SplitError::FileNotFound(input_path));
    }

    let mut doc = Document::load(&input_path)
        .map_err(|e| SplitError::OpenError(e.to_string()))?;

    let page_count = doc.get_pages().len() as i32;
    
    // Validate page numbers
    for &page in &pages {
        if page < 1 || page > page_count {
            return Err(SplitError::InvalidPageRange(
                format!("Page {} is out of range (1-{})", page, page_count)
            ));
        }
    }

    // Sort and deduplicate pages
    let mut sorted_pages = pages.clone();
    sorted_pages.sort();
    sorted_pages.dedup();
    let pages_to_keep: Vec<u32> = sorted_pages.iter().map(|&p| p as u32).collect();

    // Get all pages
    let all_pages = doc.get_pages();
    
    // Collect the page references to keep
    let mut page_refs_to_keep: Vec<Object> = Vec::new();
    let mut page_objects_to_copy: BTreeMap<ObjectId, ObjectId> = BTreeMap::new();
    
    // First pass: identify pages to keep
    for &page_num in &pages_to_keep {
        if let Some((page_id, _)) = all_pages.get(&(page_num as usize)) {
            if let Ok(page_obj) = doc.get_object(*page_id) {
                page_refs_to_keep.push(Object::Reference(*page_id));
            }
        }
    }

    // Create new document
    let mut new_doc = Document::with_version("1.7");
    
    // Track max ID for the new document
    let mut max_id: ObjectId = (0, 0);
    
    // Copy pages from source to new document
    let mut new_page_refs: Vec<Object> = Vec::new();
    
    for page_ref in &page_refs_to_keep {
        if let Object::Reference(old_id) = page_ref {
            if let Ok(page_obj) = doc.get_object(*old_id) {
                max_id.0 += 1;
                let new_id: ObjectId = (max_id.0, 0);
                page_objects_to_copy.insert(*old_id, new_id);
                new_doc.objects.insert(new_id, page_obj);
                new_page_refs.push(Object::Reference(new_id));
            }
        }
    }

    // Create pages dictionary
    let pages_id = new_doc.new_object_id();
    let mut pages_dict = lopdf::Dictionary::new();
    pages_dict.set("Type", Object::Name(b"Pages".to_vec()));
    pages_dict.set("Kids", Object::Array(new_page_refs.clone()));
    pages_dict.set("Count", Object::Integer(pages_to_keep.len() as i64));
    
    // Create resources
    let resources_id = new_doc.new_object_id();
    let resources_dict = lopdf::Dictionary::new();
    new_doc.objects.insert(resources_id, Object::Dictionary(resources_dict));
    pages_dict.set("Resources", Object::Reference(resources_id));
    
    // Set default media box (Letter size)
    let media_box = lopdf::Array::from([
        Object::Real(0.0),
        Object::Real(0.0),
        Object::Real(612.0),
        Object::Real(792.0),
    ]);
    pages_dict.set("MediaBox", Object::Array(media_box));
    
    new_doc.objects.insert(pages_id, Object::Dictionary(pages_dict));
    
    // Create catalog
    let catalog_id = new_doc.new_object_id();
    let mut catalog_dict = lopdf::Dictionary::new();
    catalog_dict.set("Type", Object::Name(b"Catalog".to_vec()));
    catalog_dict.set("Pages", Object::Reference(pages_id));
    new_doc.objects.insert(catalog_id, Object::Dictionary(catalog_dict));
    
    new_doc.trailer.set("Root", Object::Reference(catalog_id));
    
    // Save the split PDF
    new_doc.save(&output_path)
        .map_err(|e| SplitError::SaveError(e.to_string()))?;

    Ok(output_path)
}

/// Split a PDF into individual pages (one file per page)
pub fn split_to_single_pages(input_path: String, output_dir: String) -> Result<Vec<String>, SplitError> {
    let path_buf = PathBuf::from(&input_path);
    if !path_buf.exists() {
        return Err(SplitError::FileNotFound(input_path));
    }

    let doc = Document::load(&input_path)
        .map_err(|e| SplitError::OpenError(e.to_string()))?;

    let pages = doc.get_pages();
    let page_count = pages.len();
    
    let mut output_paths: Vec<String> = Vec::new();
    
    for page_num in 1..=page_count {
        let output_path = format!("{}/page_{}.pdf", output_dir, page_num);
        match extract_pages(input_path.clone(), vec![page_num as i32], output_path.clone()) {
            Ok(path) => output_paths.push(path),
            Err(e) => return Err(e),
        }
    }

    Ok(output_paths)
}

/// Get the list of pages in a PDF
pub fn get_pages(path: String) -> Result<Vec<i32>, SplitError> {
    let path_buf = PathBuf::from(&path);
    if !path_buf.exists() {
        return Err(SplitError::FileNotFound(path));
    }

    let doc = Document::load(&path)
        .map_err(|e| SplitError::OpenError(e.to_string()))?;

    let pages = doc.get_pages();
    let page_nums: Vec<i32> = pages.keys().map(|k| *k as i32).collect();

    Ok(page_nums)
}
