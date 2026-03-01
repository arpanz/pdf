use lopdf::{Object, ObjectId};
use std::collections::BTreeMap;
use std::path::PathBuf;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum CompressError {
    #[error("Failed to open PDF: {0}")]
    OpenError(String),
    #[error("Failed to compress PDF: {0}")]
    CompressError(String),
    #[error("Failed to save PDF: {0}")]
    SaveError(String),
    #[error("Invalid compression level: {0}")]
    InvalidLevel(String),
    #[error("File not found: {0}")]
    FileNotFound(String),
}

/// Compression level: 0 = least compression, 9 = most compression
pub fn compress_pdf(input_path: String, level: i32, output_path: String) -> Result<String, CompressError> {
    let path_buf = PathBuf::from(&input_path);
    if !path_buf.exists() {
        return Err(CompressError::FileNotFound(input_path));
    }

    if level < 0 || level > 9 {
        return Err(CompressError::InvalidLevel("Level must be between 0 and 9".to_string()));
    }

    let mut doc = Document::load(&input_path)
        .map_err(|e| CompressError::OpenError(e.to_string()))?;

    // Compress objects based on level
    // Level 0-3: Light compression (remove unnecessary whitespace)
    // Level 4-6: Medium compression (compress streams)
    // Level 7-9: Maximum compression (recompress all streams)
    
    if level >= 4 {
        // Try to compress streams
        compress_streams(&mut doc, level);
    }

    // Remove unnecessary objects
    remove_unnecessary_objects(&mut doc);

    // Rebuild the document to optimize structure
    doc.rebuild();

    // Save with compression
    let compression = match level {
        0..=3 => false,
        _ => true,
    };
    
    doc.save_with_compression(&output_path, compression)
        .map_err(|e| CompressError::SaveError(e.to_string()))?;

    Ok(output_path)
}

fn compress_streams(doc: &mut Document, level: i32) {
    // Get all object IDs that have streams
    let stream_ids: Vec<ObjectId> = doc.objects
        .iter()
        .filter(|(_, obj)| matches!(obj, Object::Stream(_)))
        .map(|(id, _)| *id)
        .collect();

    // Try to compress each stream
    for id in stream_ids {
        if let Ok(Object::Stream(ref mut stream)) = doc.get_object_mut(id) {
            // Only attempt recompression for higher levels
            if level >= 7 {
                // Try to recompress the stream content
                let _ = stream recompress();
            }
            
            // For all levels >= 4, ensure streams are compressed
            if let Ok(content) = stream.content.clone() {
                if !content.is_empty() {
                    // Check if already compressed
                    let filter = stream.dict.get(b"Filter");
                    if filter.is_none() {
                        // Add compression filter
                        stream.dict.set("Filter", Object::Name(b"FlateDecode".to_vec()));
                    }
                }
            }
        }
    }
}

fn remove_unnecessary_objects(doc: &mut Document) {
    // Remove empty objects
    let objects_to_remove: Vec<ObjectId> = doc.objects
        .iter()
        .filter(|(_, obj)| is_empty_object(obj))
        .map(|(id, _)| *id)
        .collect();

    for id in objects_to_remove {
        doc.objects.remove(&id);
    }
}

fn is_empty_object(obj: &Object) -> bool {
    match obj {
        Object::Dictionary(dict) => dict.is_empty(),
        Object::Array(arr) => arr.is_empty(),
        Object::String(s, _) => s.is_empty(),
        Object::Name(n) => n.is_empty(),
        _ => false,
    }
}

/// Get the current compression level of a PDF
pub fn get_compression_info(path: String) -> Result<CompressionInfo, CompressError> {
    let path_buf = PathBuf::from(&path);
    if !path_buf.exists() {
        return Err(CompressError::FileNotFound(path));
    }

    let doc = Document::load(&path)
        .map_err(|e| CompressError::OpenError(e.to_string()))?;

    let page_count = doc.get_pages().len() as i32;
    
    // Count streams
    let stream_count = doc.objects
        .iter()
        .filter(|(_, obj)| matches!(obj, Object::Stream(_)))
        .count();

    // Count compressed streams
    let compressed_count = doc.objects
        .iter()
        .filter(|(_, obj)| {
            if let Object::Stream(stream) = obj {
                stream.dict.get(b"Filter").is_some()
            } else {
                false
            }
        })
        .count();

    Ok(CompressionInfo {
        page_count,
        stream_count: stream_count as i32,
        compressed_streams: compressed_count as i32,
    })
}

#[derive(Debug, Clone)]
pub struct CompressionInfo {
    pub page_count: i32,
    pub stream_count: i32,
    pub compressed_streams: i32,
}
