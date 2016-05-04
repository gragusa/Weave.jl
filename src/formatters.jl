
function format(doc::WeaveDoc)
    formatted = AbstractString[]
    docformat = doc.format

    #Complete format dictionaries with defaults
    formatdict = docformat.formatdict
    get!(formatdict, :termstart, formatdict[:codestart])
    get!(formatdict, :termend, formatdict[:codeend])
    get!(formatdict, :out_width, nothing)
    get!(formatdict, :out_height, nothing)
    get!(formatdict, :fig_pos, nothing)
    get!(formatdict, :fig_env, nothing)


    for chunk in copy(doc.chunks)
        result = format_chunk(chunk, formatdict, docformat)
        push!(formatted, result)
    end

    return formatted
end


function format_chunk(chunk::DocChunk, formatdict, docformat)
    return chunk.content
end


function format_chunk(chunk::CodeChunk, formatdict, docformat)
    #Fill undefined options with format specific defaults
    chunk.options[:out_width] == nothing &&
        (chunk.options[:out_width] =  formatdict[:out_width])
    chunk.options[:fig_pos] == nothing &&
        (chunk.options[:fig_pos] =  formatdict[:fig_pos])

    #Only use floats if chunk has caption or sets fig_env
    if chunk.options[:fig_cap] != nothing && chunk.options[:fig_env] == nothing
        (chunk.options[:fig_env] =  formatdict[:fig_env])
    end


    if haskey(formatdict, :indent)
        chunk.content = indent(chunk.content, formatdict[:indent])
    end

    if !chunk.options[:eval]
        if chunk.options[:echo]
            result = "$(formatdict[:codestart])$(chunk.content)\n$(formatdict[:codeend])"
            return result
        else
            r = ""
            return r
        end
    end

    if chunk.options[:term]
        result = format_termchunk(chunk, formatdict)
    else

    if chunk.options[:echo]
        result = "$(formatdict[:codestart])$(chunk.content)\n$(formatdict[:codeend])\n"
    else
        result = ""
    end

    if (strip(chunk.output)!= "" || strip(chunk.rich_output) != "") && (chunk.options[:results] != "hidden")
        if chunk.options[:results] != "markup" && chunk.options[:results] != "hold"
            strip(chunk.output) ≠ "" && (result *= "$(chunk.output)\n")
            strip(chunk.rich_output) ≠ "" && (result *= "$(chunk.rich_output)\n")
        else
            if chunk.options[:wrap]
                chunk.output = "\n" * wraplines(chunk.output,
                                        chunk.options[:line_width])
            end

            if haskey(formatdict, :indent)
                chunk.output = indent(chunk.output, formatdict[:indent])
            end
            strip(chunk.output) ≠ "" &&
                (result *= "$(formatdict[:outputstart])$(chunk.output)\n$(formatdict[:outputend])\n")
            strip(chunk.rich_output) ≠ "" && (result *= chunk.rich_output * "\n")
        end
    end

    end

    #Handle figures
    if chunk.options[:fig] && length(chunk.figures) > 0
        if chunk.options[:include]
            result *= formatfigures(chunk, docformat)
        end
    end

    return result
end

function format_termchunk(chunk, formatdict)
    if chunk.options[:echo] && chunk.options[:results] != "hidden"
        result = "$(formatdict[:termstart])$(chunk.output)\n" * "$(formatdict[:termend])\n"
        #chunk.options[:term_state] == :text && (result*= "$(formatdict[:termend])\n")
    else
        result = ""
    end
    return result
end

function indent(text, nindent)
    return join(map(x->
                    string(repeat(" ", nindent), x), split(text, "\n")), "\n")
end


function wraplines(text, line_width=75)
    result = AbstractString[]
    lines = split(text, "\n")
    for line in lines
        if length(line) > line_width
            push!(result, wrapline(line, line_width))
        else
            push!(result, line)
        end
    end

    #return result
    return strip(join(result, "\n"))
end

function wrapline(text, line_width=75)
result = ""
    while length(text) > line_width
        result*= text[1:line_width] * "\n"
        text = text[(line_width+1):end]
    end
result *= text
end


type Tex
    description::AbstractString
    formatdict::Dict{Symbol,Any}
end

const tex = Tex("Latex with custom code environments",
                @compat Dict{Symbol,Any}(:codestart => "\\begin{juliacode}",
                                         :codeend => "\\end{juliacode}",
                                         :outputstart => "\\begin{juliaout}",
                                         :outputend => "\\end{juliaout}",
                                         :termstart => "\\begin{juliaterm}",
                                         :termend => "\\end{juliaterm}",
                                         :fig_ext => ".pdf",
                                         :extension =>"tex",
                                         :out_width=> "\\linewidth",
                                         :fig_env=> "figure",
                                         :fig_pos => "htpb",
                                         :doctype => "tex",
                                         :mimetypes => ["application/pdf", "image/png", "text/latex", "text/plain"]
                                         ))

const texminted = Tex("Latex using minted for highlighting",
                      @compat Dict{Symbol,Any}(
                                         :codestart => "\\begin{minted}[mathescape, fontsize=\\small, xleftmargin=0.5em]{julia}",
                                         :codeend => "\\end{minted}",
                                         :outputstart => "\\begin{minted}[fontsize=\\small, xleftmargin=0.5em, mathescape, frame = leftline]{text}",
                                         :outputend => "\\end{minted}",
                                         :termstart=> "\\begin{minted}[fontsize=\\footnotesize, xleftmargin=0.5em, mathescape]{julia}",
                                         :termend => "\\end{minted}",
                                         :fig_ext => ".pdf",
                                         :extension =>"tex",
                                         :out_width => "\\linewidth",
                                         :fig_env=> "figure",
                                         :fig_pos => "htpb",
                                         :doctype => "texminted",
                                         :mimetypes => ["application/pdf", "image/png", "text/latex", "text/plain"]
                                         ))

type Pandoc
  description::AbstractString
  formatdict::Dict{Symbol,Any}
end


const pandoc = Pandoc("Pandoc markdown",
                        @compat Dict{Symbol,Any}(
                                :codestart => "~~~~{.julia}",
                                :codeend=>"~~~~~~~~~~~~~\n\n",
                                :outputstart=>"~~~~",
                                :outputend=>"~~~~\n\n",
                                :fig_ext=>".png",
                                :out_width=>nothing,
                                :extension=>"md",
                                #Prefer png figures for markdown conversion, svg doesn't work with latex
                                :mimetypes => ["image/png", "image/jpg", "image/svg+xml", "text/markdown", "text/plain"],
                                :doctype=>"pandoc"
                                               ))


const md2html = Pandoc("Markdown to HTML (requires Pandoc)",
                      @compat Dict{Symbol,Any}(
                              :codestart => "````julia",
                              :codeend=> "````\n\n",
                              :outputstart=> "````",
                              :outputend=> "````\n\n",
                              :fig_ext=> ".svg",
                              :extension=> "md",
                              :mimetypes => ["image/svg+xml", "image/png", "image/jpg",
                                  "text/html", "text/markdown",  "text/plain"],
                              :doctype=> "md2html"))

const md2pdf = Pandoc("Markdown to pdf (requires Pandoc and xelatex)",
                      @compat Dict{Symbol,Any}(
                              :codestart => "````julia",
                              :codeend=> "````\n\n",
                              :outputstart=> "````",
                              :outputend=> "````\n\n",
                              :fig_ext=> ".pdf",
                              :extension=> "md",
                              :mimetypes => ["application/pdf", "image/png", "image/jpg",
                                  "text/latex", "text/plain"],
                              :doctype=> "md2pdf"))



type Markdown
   description::AbstractString
   formatdict::Dict{Symbol,Any}
end

const github = Markdown("Github markdown",
                        @compat Dict{Symbol,Any}(
                                :codestart => "````julia",
                                :codeend=> "````\n\n",
                                :outputstart=> "````",
                                :outputend=> "````\n\n",
                                :fig_ext=> ".png",
                                :extension=> "md",
                                :doctype=> "github"
                                               ))

type MultiMarkdown
  description::AbstractString
  formatdict::Dict{Symbol,Any}
end

const multimarkdown = MultiMarkdown("MultiMarkdown",
                        @compat Dict{Symbol,Any}(
                                :codestart => "````julia",
                                :codeend=> "````\n\n",
                                :outputstart=> "````",
                                :outputend=> "````\n\n",
                                :fig_ext=> ".png",
                                :extension=> "md",
                                :doctype=> "github"
                                               ))


type Rest
    description::AbstractString
    formatdict::Dict{Symbol,Any}
end

const rst = Rest("reStructuredText and Sphinx",
                 @compat Dict{Symbol,Any}(
                                :codestart => ".. code-block:: julia\n",
                                :codeend => "\n\n",
                                :outputstart => "::\n",
                                :outputend => "\n\n",
                                :indent=> 4,
                                :fig_ext => ".png",
                                :extension => "rst",
                                :out_width => "15 cm",
                                :doctype => "rst"
                                ))

type AsciiDoc
    description::AbstractString
    formatdict::Dict{Symbol,Any}
end

#asciidoc -b html5 -a source-highlighter=pygments ...
const adoc = AsciiDoc("AsciiDoc",
        @compat Dict{Symbol,Any}(
        :codestart => "[source,julia]\n--------------------------------------",
        :codeend => "--------------------------------------\n\n",
        :outputstart => "--------------------------------------",
        :outputend => "--------------------------------------\n\n",
        :fig_ext => ".png",
        :extension => "txt",
        :out_width => "600",
        :doctype => "asciidoc"
))


function formatfigures(chunk, docformat::Tex)
    fignames = chunk.figures
    caption = chunk.options[:fig_cap]
    width = chunk.options[:out_width]
    height = chunk.options[:out_height]
    f_pos = chunk.options[:fig_pos]
    f_env = chunk.options[:fig_env]
    f_align = chunk.options[:fig_align]
    result = ""
    figstring = ""

    #Set size
    attribs = ""
    width == nothing || (attribs = "width=$width")
    (attribs != "" && height != nothing ) && (attribs *= ",")
    height == nothing    || (attribs *= "height=$height")

    if f_env != nothing
        result *= """\\begin{$f_env}[$f_pos]\n"""
    end

    if f_align == "center"
        align_string = "\\center\n"
    elseif f_align == "right"
        align_string = "\\raggedright\n"
    elseif f_align == "left"
        align_string = "\\raggedleft\n"
    else
        align_string = ""
    end

    for fig = fignames

        if splitext(fig)[2] == ".tex" #Tikz figures
            figstring *= "\\resizebox{$width}{!}{\\input{$fig}}\n"
        else
            figstring *= "\\includegraphics[$attribs]{$fig}\n"
        end
    end

    # Figure environment
    if caption != nothing
        result *= string("$align_string",
                         "$figstring",
                         "\\caption{$caption}\n")
    else
        result *= string("$align_string",
                         "$figstring")
    end

    if chunk.options[:name] != nothing && f_env !=nothing
        label = chunk.options[:name]
        result *= "\\label{fig:$label}\n"
    end

    if f_env != nothing
        result *= "\\end{$f_env}\n"
    end

   return result
end

function _format_aligned_figure(docformat::Pandoc, fig, falign, width, height, caption)
    result = ""
    attribs = ""
    #Build figure attibutes
    width == nothing || (attribs = "width=$width")
    (attribs ≠ "" && height ≠ nothing ) && (attribs *= " ")
    height == nothing   || (attribs *= "height=$height")
    attribs == ""    || (attribs = "{$attribs}")

    if falign=="default"
        result *= "![$caption]($fig)$attribs\\ \n\n"
    else
        result *= "<div class='figure' style='text-align: $falign'>\n"
        result *= "<img src='$fig' alt = '$caption' width='$width' height='$height'>\n"
        if caption!=nothing
            result *= "<p class='caption'>\n $caption </p>\n</div>\n"
        end
    end
    result
end

function formatfigures(chunk, docformat::Pandoc)
    fignames = chunk.figures
    caption = chunk.options[:fig_cap]
    falign = chunk.options[:fig_align]
    result = ""
    figstring = ""
    width = chunk.options[:out_width]
    height = chunk.options[:out_height]

    length(fignames) > 0 || (return "")

    if caption != nothing
        result *= _format_aligned_figure(docformat, fignames[1], falign, width, height, caption)
        for fig = fignames[2:end]
            result *= _format_aligned_figure(docformat, fig, falign, width, height, nothing)
            println("Warning, only the first figure gets a caption\n")
        end
    else
        for fig in fignames
            result *= _format_aligned_figure(docformat, fig, falign, width, height, "")
            # result *= "![]($fig)$attribs\\ \n\n"
        end
    end
    return result
end


function _format_aligned_figure(docformat::Markdown, fig, falign, width, height, caption)
    result = ""
    if falign=="default"
        result *= "![$caption]($fig)\n"
    else
        result *= "<div class='figure' style='text-align: $falign'>\n"
        result *= "<img src='$fig' alt='$caption' width='$width' heigh='$height'>\n"
        if caption!=nothing
            result *= "<p class='caption'>\n $caption </p>\n"
        end
        result *= "</div>\n"
    end
    result
end

function formatfigures(chunk, docformat::Markdown)
    fignames = chunk.figures
    caption = chunk.options[:fig_cap]
    f_align = chunk.options[:fig_align]
    width = chunk.options[:out_width]
    height = chunk.options[:out_height]
    result = ""
    figstring = ""

    length(fignames) > 0 || (return "")

    if caption != nothing
        result *= _format_aligned_figure(docformat, fig, falign, width, heigh, caption)
        for fig = fignames[2:end]
            result *= _format_aligned_figure(docformat, fig, falign, width, height, nothing)
            if fig_align == "default"
                println("Warning, only the first figure gets a caption\n")
            end
        end
    else
        for fig in fignames
            result *= _format_aligned_figure(docformat, fig, falign, width, height, nothing)
        end
    end
    return result
end

function formatfigures(chunk, docformat::MultiMarkdown)
    fignames = chunk.figures
    caption = chunk.options[:fig_cap]
    result = ""
    figstring = ""

    if chunk.options[:out_width] == nothing
      width = ""
    else
      width = "width=$(chunk.options[:out_width])"
    end

    length(fignames) > 0 || (return "")

    if caption != nothing
       result *= "![$caption][$(fignames[1])]\n\n"
       result *= "[$(fignames[1])]: $(fignames[1]) $width\n"
        for fig = fignames[2:end]
          result *= "![][$fig]\n\n"
          result *= "[$fig]: $fig $width\n"
          println("Warning, only the first figure gets a caption\n")
        end
    else
        for fig in fignames
          result *= "![][$fig]\n\n"
          result *= "[$fig]: $fig $width\n"
        end
    end
    return result
end


function formatfigures(chunk, docformat::Rest)
    fignames = chunk.figures
    caption = chunk.options[:fig_cap]
    width = chunk.options[:out_width]
    result = ""
    figstring = ""

    for fig=fignames
        figstring *= @sprintf(".. image:: %s\n   :width: %s\n\n", fig, width)
    end

    if caption != nothing
        result *= string(".. figure:: $(fignames[1])\n",
                         "   :width: $width\n\n",
                         "   $caption\n\n")
    else
        result *= figstring
        return result
    end
end


function formatfigures(chunk, docformat::AsciiDoc)
    fignames = chunk.figures
    caption = chunk.options[:fig_cap]
    width = chunk.options[:out_width]
    result = ""
    figstring = ""


    for fig=fignames
        figstring *= @sprintf("image::%s[width=%s]\n", fig, width)
    end


    if caption != nothing
        result *= string("image::$(fignames[1])",
        "[width=$width,",
        "title=\"$caption\"]")
    else
        result *= figstring
        return result
    end
end


#Add new supported formats here
const formats = @compat Dict{AbstractString, Any}("tex" => tex,
                                          "texminted" => texminted,
                                          "pandoc" => pandoc,
                                          "md2html" => md2html,
                                          "md2pdf" => md2pdf,
                                          "github" => github,
                                          "multimarkdown" => multimarkdown,
                                          "rst" => rst,
                                          "asciidoc" => adoc
                                          )
