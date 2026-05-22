require 'fileutils'

# List of test documents to convert
FILES = [
  "Atividade Normas 25010 e 15288 — SIDERA PREDICT.md",
  "Documento A — Base Conceitual de Teste.md",
  "Documento B — Processo de Teste.md",
  "Documento C — Técnicas e Casos de Teste.md",
  "Documento D — Resultados dos Testes.md",
  "Documento D — Execução e Resultados dos Testes.md",
  "Documento E — Implementação dos Testes de Integração.md"
]

DOC_DIR = File.dirname(__FILE__)

puts "--- Iniciando conversão de Markdown para PDF estilo GitHub ---"

FILES.each do |file_name|
  file_path = File.join(DOC_DIR, file_name)
  unless File.exist?(file_path)
    puts "⚠️ Arquivo não encontrado: #{file_name}"
    next
  end

  puts "\nProcessando: #{file_name}"
  
  # Read full raw markdown content (no custom parsing needed!)
  markdown_content = File.read(file_path, encoding: "utf-8")

  # Create temp files for compiling
  temp_md_path = File.join(DOC_DIR, "temp_#{File.basename(file_name, '.md')}.md")
  temp_body_path = File.join(DOC_DIR, "temp_body_#{File.basename(file_name, '.md')}.html")
  
  File.write(temp_md_path, markdown_content, encoding: "utf-8")

  # Run marked CLI to compile markdown to HTML body
  system("npx --yes marked --gfm -i \"#{temp_md_path}\" -o \"#{temp_body_path}\"")
  
  body_html = File.read(temp_body_path, encoding: "utf-8")

  # Build the final GitHub-style HTML with A4 margins
  final_html = <<~HTML
    <!DOCTYPE html>
    <html lang="pt-BR">
    <head>
      <meta charset="UTF-8">
      <title>#{File.basename(file_name, '.md')}</title>
      <style>
        @page {
          size: A4;
          margin: 2cm;
        }

        body {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji";
          color: #24292f;
          line-height: 1.5;
          font-size: 11pt;
          background-color: #ffffff;
          margin: 0;
          padding: 0;
        }

        /* GitHub MD Elements */
        h1, h2, h3, h4, h5, h6 {
          font-weight: 600;
          color: #24292f;
          margin-top: 24px;
          margin-bottom: 16px;
          line-height: 1.25;
        }

        h1 {
          font-size: 24pt;
          border-bottom: 1px solid #d0d7de;
          padding-bottom: 0.3em;
        }

        h2 {
          font-size: 18pt;
          border-bottom: 1px solid #d0d7de;
          padding-bottom: 0.3em;
          margin-top: 30px;
        }

        h3 {
          font-size: 14pt;
        }

        h4 {
          font-size: 12pt;
        }

        p {
          margin-top: 0;
          margin-bottom: 16px;
          text-align: justify;
        }

        li, td, blockquote p {
          text-align: justify;
        }

        ul, ol {
          margin-top: 0;
          margin-bottom: 16px;
          padding-left: 2em;
        }

        li {
          margin-bottom: 0.25em;
        }

        pre {
          background-color: #f6f8fa;
          border-radius: 6px;
          padding: 16px;
          margin: 20px 0;
          overflow: auto;
          page-break-inside: avoid;
          break-inside: avoid;
        }

        code {
          font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, "Liberation Mono", monospace;
          font-size: 85%;
          background-color: rgba(175, 184, 193, 0.2);
          padding: 0.2em 0.4em;
          border-radius: 6px;
        }

        pre code {
          background-color: transparent;
          color: inherit;
          padding: 0;
          border-radius: 0;
          font-size: 85%;
        }

        table {
          width: 100%;
          border-collapse: collapse;
          margin: 24px 0;
          page-break-inside: auto;
          break-inside: auto;
          font-size: 10pt;
        }

        tr {
          page-break-inside: avoid;
          break-inside: avoid;
        }

        th, td {
          padding: 6px 13px;
          border: 1px solid #d0d7de;
          line-height: 1.5;
        }

        th {
          background-color: #f6f8fa;
          font-weight: 600;
        }

        tr:nth-child(even) {
          background-color: #f6f8fa;
        }

        blockquote {
          margin: 16px 0;
          padding: 0 1em;
          color: #57606a;
          border-left: 0.25em solid #d0d7de;
          page-break-inside: avoid;
          break-inside: avoid;
        }

        hr {
          height: 0.25em;
          padding: 0;
          margin: 24px 0;
          background-color: #d0d7de;
          border: 0;
        }

        /* Clean Status Badges matching GitHub colors */
        .status-badge {
          display: inline-flex;
          align-items: center;
          gap: 4px;
          padding: 2px 10px;
          border-radius: 2em;
          font-size: 8.5pt;
          font-weight: 600;
          white-space: nowrap;
        }

        .status-success {
          background-color: #dafbe1;
          color: #1a7f37;
          border: 1px solid rgba(26, 127, 55, 0.2);
        }

        .status-danger {
          background-color: #ffe3e3;
          color: #cf222e;
          border: 1px solid rgba(207, 34, 46, 0.2);
        }
      </style>
    </head>
    <body>
      
      <div class="markdown-body">
        #{body_html}
      </div>

      <script>
        document.addEventListener("DOMContentLoaded", () => {
          document.querySelectorAll("td").forEach(cell => {
            const text = cell.textContent.trim();
            if (text.startsWith("✅") || text.startsWith("❌")) {
              const isOk = text.startsWith("✅");
              const label = text.replace(/^[✅❌]/, "").trim();
              cell.innerHTML = `<span class="status-badge ${isOk ? 'status-success' : 'status-danger'}">${isOk ? '✅' : '❌'} ${label}</span>`;
            }
          });
        });
      </script>
    </body>
    </html>
  HTML

  # Render PDF using headless Chrome
  temp_html_path = File.join(DOC_DIR, "temp_#{File.basename(file_name, '.md')}.html")
  output_pdf_path = File.join(DOC_DIR, file_name.sub(".md", ".pdf"))

  File.write(temp_html_path, final_html, encoding: "utf-8")
  
  puts "- Gerando PDF usando headless Google Chrome..."
  begin
    system("google-chrome --headless --disable-gpu --print-to-pdf=\"#{output_pdf_path}\" --no-pdf-header-footer \"#{temp_html_path}\"")
    puts "✅ PDF gerado com sucesso: #{File.basename(output_pdf_path)}"
  rescue => e
    puts "❌ Erro ao gerar PDF: #{e.message}"
  ensure
    # Cleanup all temp files
    File.delete(temp_html_path) if File.exist?(temp_html_path)
    File.delete(temp_md_path) if File.exist?(temp_md_path)
    File.delete(temp_body_path) if File.exist?(temp_body_path)
  end
end

puts "\n--- Conversão concluída com sucesso! ---"
