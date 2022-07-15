#!/usr/bin/perl

use File::Temp qw/ tempfile tempdir/;
use File::Basename;
use DateTime;
use DateTime::Format::Strptime;
my $tmpdir = tempdir(CLEANUP => 1);

my $file = $ARGV[0];
my $title = $ARGV[1];
my $author = $ARGV[2];

open my $fh, '<', $file or die;
my $intext = 0;
my $inpoem = 0;
my $output = "";
my %notes;
for (<$fh>)
  {
    if (/\# Story Start/)
      {
        $intext = 1;
      }
    elsif ($intext==1 and /\# Start Poem/)
      {
        $output = $output . "#+BEGIN_EXAMPLE\n";
      }
    elsif ($intext==1 and /\# End Poem/)
      {
        $output = $output . "#+END_EXAMPLE\n";
      }
    elsif (/\# Story End/)
      {
        $intext = 0;
      }
    elsif ($intext == 1)
      {
        if (/\[([a-zA-Z0-9 ]+):(.*)\]/)
          {
            my $key = $1;
            my $val = $2;

            if (exists($notes{$key}))
              {
                push @{$notes{$key}}, $val;
              }
            else
              {
                $notes{$key} = [$val];
              }
          }
        else
          {
            my $line = $_;
            $line =~ s/\*\*\*/*/g;
            $output = $output . $line;
          }
      }

  }

close $fh;

my @lines = split "\n", $output;

my $notes_output = "";
$notes_output = $notes_output . "#+OPTIONS: toc:nil\n";
$notes_output = $notes_output . "#+TITLE: Notes\n";

for (keys %notes)
  {
    $notes_output = $notes_output . "* $_\n\n";
    my @toadd = @{$notes{$_}};
    my $i = 1;
    for (@toadd)
      {
        $notes_output = $notes_output . "$i. $_\n\n";
        $i = $i + 1;
      }
    $notes_output = $notes_output . "\n";
  }


my $filename;
($fh, $filename) = tempfile(DIR => $tmpdir);


print $fh $output;
close $fh;

my $notesfn;
($fh, $notesfn) = tempfile(DIR => $tmpdir);

print $fh $notes_output;
close $fh;

my $tmptex1;

($fh, $tmptex1) = tempfile(DIR => $tmpdir);

`pandoc -o $tmptex1 -t latex -f org --top-level-division=part $filename`;

close $fh;

my $top_blurb = "\\documentclass[12pt,ebook,oneside,openleft,final]{memoir}
\\author{$author}
\\title{$title}
\\usepackage{hyperref}
\\usepackage[T1]{fontenc}
\\usepackage{epigraph}
\\usepackage{tgschola}
\\usepackage{verse}
\\setlength\\epigraphwidth{.8\\textwidth}
\\newcommand{\\mytime}[2]{\\noindent\\emph{#1}\\\\ \\emph{#2}\\\\}
\\newcommand{\\epi}[1]{\\epigraph{\\emph{#1}}{}{}}
%\\setlength\\midchapskip{10pt}
\\usepackage{calc}
\\renewcommand\\chapternamenum{}
\\renewcommand\\printchaptername{}
\\renewcommand\\chapnumfont{\\Large\\centering}
\\renewcommand\\chaptitlefont{\\LARGE\\centering}
\\renewcommand\\partnumfont{\\normalfont\\Huge}
\\renewcommand\\partnamefont{\\normalfont\\Huge}
\\renewcommand\\parttitlefont{\\normalfont\\Huge\\centering}
\\renewcommand\\afterchapternum{\\par\\nobreak\\vskip\\midchapskip\\hrule\\vskip\\midchapskip}
\\begin{document}
\\medievalpage
\\pagestyle{plain}
\\begin{titlingpage}
  \\HUGE
  \\begin{center}
    \\noindent $title
  \\end{center}

  \\vspace{10em}
  \\begin{center}
    \\LARGE
    $author
  \\end{center}
\\end{titlingpage}\n";


my $bottom_blurb = "\n \\end{document}\n";

my $tmptex2;
my $fh_out;
($fh_out, $tmptex2) = tempfile(DIR => $tmpdir);

open my $fh_in, '<', $tmptex1 or die;

print $fh_out $top_blurb;

for (<$fh_in>)
  {
    print $fh_out $_;
  }

print $fh_out $bottom_blurb;

close $fh_out;
close $fh_in;

open $fh_in, '<', $tmptex2 or die;

my $inpoem = 0;
my $text = "";
for (<$fh_in>)
  {
    if (/\\begin\{verbatim\}/)
      {
        $text = $text . "\\begin{verse}\n";
        $inpoem = 1;
      }
    elsif (/\\end\{verbatim\}/)
      {
        $text = $text . "\\end{verse}\n";
        $inpoem = 0;
      }
    else
      {
        my $out = $_;
        if ($inpoem == 1)
          {
            chomp $out;
            if (length($out)==0)
              {
                $text = $text . "\n";
              }
            else
              {
                $text = $text . $out . "\\\\" . "\n";
              }
          }
        else
          {
            $text = $text . $out;
          }
      }

  }

close $fh_in;
$text =~ s/\\\\\n\n/\n\n/g;

my $tmptex3;

($fh_out, $tmptex3) = tempfile(DIR => $tmpdir);
my @char = split(//, $text);

my $in_quote = 0;

for (@char)
  {
    if ($_ eq '"')
      {
        if ($in_quote == 1)
          {
            print $fh_out "''";
            $in_quote = 0;
          }
        else
          {
            print $fh_out "``";
            $in_quote = 1;
          }
      }
    else
      {
        print $fh_out $_;
      }
  }

close $fh_out;

my $titlef = $title;
$titlef =~ s/ /_/g;

my $authorf = $author;
$authorf =~ s/ /_/g;

my $fname = "$titlef" . "_" . "$authorf";

`pandoc -o "$fname.docx" -f latex --top-level-division=part $tmptex3`;

`pdflatex -output-directory $tmpdir $tmptex3 > tmp.log`;
`pdflatex -output-directory $tmpdir $tmptex3`;

my $base = basename($tmptex3);

`cp $tmptex3.pdf "$fname.pdf"`;

my $notes_out = "$fname" . "_Notes.docx";

`pandoc -o "$notes_out" -f org $notesfn`;


if (exists $notes{"start date"})
  {
    my $format = DateTime::Format::Strptime->new(
      pattern => '%Y-%m-%d',
      time_zone => 'floating',
      on_error => 'croak'
     );

    my @tmp = @{$notes{"start date"}};
    my $dt = $format->parse_datetime($tmp[0]);
    my $cur = DateTime->today(time_zone => 'floating');
    my $dur = $dt->delta_days($cur);
    my $days = $dur->in_units('days');
    my $words = `wc -w < $filename`;
    print $days . "," . $words . "\n";
      
  }

