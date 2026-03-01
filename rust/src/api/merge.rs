use lopdf::{Document, Object, ObjectId};
use std::collections::BTreeMap;
use std::path::PathBuf;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum PdfError {
    #[error("Failed to open PDF: {0}")]
    OpenError(String),
    #[error("Failed to merge PDFs: {0}")]
    MergeError(String),
    #[error("Failed to save PDF: {0}")]
    SaveError(String),
    #[error("Invalid page range: {0}")]
    InvalidPageRange(String),
    #[error("File not found: {0}")]
    FileNotFound(String),
}

pub struct PdfProcessor;

impl PdfProcessor {
    /// Merge multiple PDFs into a single PDF
    pub fn merge_pdfs(paths: Vec<String>, output_path: String) -> Result<String, PdfError> {
        if paths.is_empty() {
            return Err(PdfError::MergeError("No input files provided".to_string()));
        }

        if paths.len() == 1 {
            // Just copy the single file
            let src = PathBuf::from(&paths[0]);
            let dst = PathBuf::from(&output_path);
            std::fs::copy(&src, &dst)
                .map_err(|e| PdfError::SaveError(e.to_string()))?;
            return Ok(output_path);
        }

        // Load all documents
        let mut documents: Vec<Document> = Vec::new();
        for path in &paths {
            let path_buf = PathBuf::from(path);
            if !path_buf.exists() {
                return Err(PdfError::FileNotFound(path.clone()));
            }
            let doc = Document::load(path)
                .map_err(|e| PdfError::OpenError(e.to_string()))?;
            documents.push(doc);
        }

        // Start with the first document as the base
        let mut base_doc = documents.remove(0);
        
        // Track max object id across all documents
        let mut max_id: ObjectId = *base_doc.max_id.keys().max().unwrap_or(&(0, 0));
        
        // Create a mapping of old object IDs to new object IDs for each document
        let mut all_id_mappings: Vec<BTreeMap<ObjectId, ObjectId>> = Vec::new();
        
        for doc in &documents {
            let mut id_mapping: BTreeMap<ObjectId, ObjectId> = BTreeMap::new();
            
            // Get all objects from the document
            let objects = doc.objects.clone();
            
            for (old_id, _) in &objects {
                max_id.0 += 1;
                id_mapping.insert(*old_id, max_id);
            }
            
            all_id_mappings.push(id_mapping);
        }
        
        // Get pages from all documents and add them to base document
        let mut page_refs: Vec<Object> = Vec::new();
        
        // Add pages from base document
        let base_pages = base_doc.get_pages();
        for (page_num, _) in base_pages {
            if let Ok(page_ref) = base_doc.get_page_reference(page_num) {
                page_refs.push(Object::Reference(page_ref));
            }
        }
        
        // Add pages from other documents
        for (doc_idx, doc) in documents.iter().enumerate() {
            let id_mapping = &all_id_mappings[doc_idx];
            let pages = doc.get_pages();
            
            for (page_num, _) in pages {
                if let Ok(catalog) = doc.catalog() {
                    if let Ok(Object::Array(ref pages_array)) = catalog.get(b"Pages") {
                        if let Ok(Object::Dictionary(ref pages_dict)) = pages_array.get(0) {
                            if let Ok(Object::Reference(_)) = pages_dict.get(b"Kids") {
                                if let Ok(page_ref) = doc.get_page_reference(page_num) {
                                    // Clone and remap the page
                                    if let Ok(page_obj) = doc.get_object(page_ref) {
                                        // Create new reference in base document
                                        max_id.0 += 1;
                                        let new_id: ObjectId = max_id;
                                        
                                        // Copy the object to base document with new ID
                                        base_doc.objects.insert(new_id, page_obj);
                                        base_doc.max_id.insert(new_id, new_id.0);
                                        
                                        page_refs.push(Object::Reference(new_id));
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Update the pages in the base document
        if let Ok(catalog) = base_doc.catalog() {
            if let Ok(Object::Dictionary(ref pages_dict)) = catalog.get(b"Pages") {
                if let Ok(Object::Reference(pages_ref)) = pages_dict.get(b"Kids") {
                    if let Ok(Object::Dictionary(mut base_pages_dict)) = base_doc.get_object(*pages_ref) {
                        base_pages_dict.set("Count", Object::Integer(page_refs.len() as i64));
                        base_pages_dict.set(
                            "Kids", 
                            Object::Array(page_refs)
                        );
                        
                        base_doc.objects.insert(*pages_ref, Object::Dictionary(base_pages_dict));
                    }
                }
            }
        }
        
        // Rebuild the document
        base_doc.rebuild();
        
        // Save the merged PDF
        base_doc.save(&output_path)
            .map_err(|e| PdfError::SaveError(e.to_string()))?;
        
        Ok(output_path)
    }

    /// Split a PDF into separate pages or a range of pages
    pub fn split_pdf(input_path: String, pages: Vec<i32>, output_path: String) -> Result<String, PdfError> {
        let path_buf = PathBuf::from(&input_path);
        if !path_buf.exists() {
            return Err(PdfError::FileNotFound(input_path));
        }

        let mut doc = Document::load(&input_path)
            .map_err(|e| PdfError::OpenError(e.to_string()))?;

        let page_count = doc.get_pages().len() as i32;
        
        // Validate page numbers
        for &page in &pages {
            if page < 1 || page > page_count {
                return Err(PdfError::InvalidPageRange(
                    format!("Page {} is out of range (1-{})", page, page_count)
                ));
            }
        }

        // Get the pages to keep (1-indexed)
        let pages_to_keep: Vec<u32> = pages.iter().map(|&p| p as u32).collect();
        
        // Get all page references
        let pages = doc.get_pages();
        let mut page_refs: Vec<Object> = Vec::new();
        
        for page_num in pages_to_keep {
            if let Some((page_id, _)) = pages.get(&(page_num as usize)) {
                if let Ok(page_ref) = doc.get_page_reference(page_num as u32) {
                    // Copy the page to new document
                    if let Ok(page_obj) = doc.get_object(*page_id) {
                        page_refs.push(Object::Reference(*page_id));
                    }
                }
            }
        }

        // Create new document with selected pages
        let mut new_doc = Document::with_version("1.7");
        
        // Create page tree
        let pages_id = new_doc.new_object_id();
        let mut pages_dict = lopdf::Dictionary::new();
        pages_dict.set("Type", Object::Name(b"Pages".to_vec()));
        pages_dict.set("Kids", Object::Array(page_refs.clone()));
        pages_dict.set("Count", Object::Integer(page_refs.len() as i64));
        
        // Create resources dictionary
        let resources_id = new_doc.new_object_id();
        let resources_dict = lopdf::Dictionary::new();
        new_doc.objects.insert(resources_id, Object::Dictionary(resources_dict));
        
        pages_dict.set("Resources", Object::Reference(resources_id));
        
        // Set media box (default letter size)
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
        
        // Copy pages from source document
        for page_ref in page_refs {
            if let Object::Reference(page_id) = page_ref {
                if let Ok(page_obj) = doc.get_object(page_id) {
                    let new_id = new_doc.new_object_id();
                    new_doc.objects.insert(new_id, page_obj);
                }
            }
        }
        
        new_doc.save(&output_path)
            .map_err(|e| PdfError::SaveError(e.to_string()))?;

        Ok(output_path)
    }

    /// Get the number of pages in a PDF
    pub fn get_page_count(path: String) -> Result<i32, PdfError> {
        let path_buf = PathBuf::from(&path);
        if !path_buf.exists() {
            return Err(PdfError::FileNotFound(path));
        }

        let doc = Document::load(&path)
            .map_err(|e| PdfError::OpenError(e.to_string()))?;

        Ok(doc.get_pages().len() as i32)
    }

    /// Get file size in bytes
    pub fn get_file_size(path: String) -> Result<u64, PdfError> {
        let path_buf = PathBuf::from(&path);
        if !path_buf.exists() {
            return Err(PdfError::FileNotFound(path));
        }

        let metadata = std::fs::metadata(&path_buf)
            .map_err(|e| PdfError::OpenError(e.to_string()))?;

        Ok(metadata.len())
    }
}
