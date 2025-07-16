use pdf_writer::{Pdf, Rect, Ref};

// Define some indirect reference ids we'll use.
let catalog_id = Ref::new(1); let page_tree_id = Ref::new(2); let page_id = Ref::new(3);

// Write a document catalog and a page tree with one A4 page that uses no resources.
let mut pdf = Pdf::new(); pdf.catalog(catalog_id).pages(page_tree_id); pdf.pages(page_tree_id).kids([page_id]).count(1);
pdf.page(page_id) .parent(page_tree_id) .media_box(Rect::new(0.0, 0.0, 595.0, 842.0)) .resources();

// Finish with cross-reference table and trailer and write to file.
std::fs::write("target/empty.pdf", pdf.finish())?;
