data "archive_file" "this" {
  type             = "zip"
  output_file_mode = "0666"
  source {
    content  = file("${path.module}/index.js")
    filename = var.filename
  }
  output_path = "${path.module}/${var.s3_key}"
}
resource "aws_s3_object" "this" {
  bucket = var.s3_bucket
  key    = var.s3_key
  source = data.archive_file.this.output_path
}
