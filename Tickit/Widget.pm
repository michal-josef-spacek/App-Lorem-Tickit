package App::Lorem::Tickit::Widget;

use parent 'Tickit::Widget';
use strict;
use warnings;

use Text::Lorem;
use Tickit::Pen;

our $VERSION = 0.01;

sub new {
	my ($class, %args) = @_;

	my $self = $class->SUPER::new(%args);
	$self->{'_active'} = 'paragraphs';
	$self->{'_mode'} = 'paragraphs';
	$self->{'_counts'} = {
		'paragraphs' => 3,
		'sentences' => 8,
		'words' => 50,
	};
	$self->{'_lorem'} = Text::Lorem->new;
	$self->{'_version'} = $args{'version'} || $VERSION;
	$self->_regenerate;

	return $self;
}

sub CAN_FOCUS {
	return 1;
}

sub cols {
	return 40;
}

sub lines {
	return 10;
}

sub on_key {
	my $self = shift;
	my ($ev) = @_;
	my $key = $ev->str;

	if ($key eq '+') {
		$self->_change_count(1);
		return 1;
	} elsif ($key eq '-') {
		$self->_change_count(-1);
		return 1;
	} elsif ($key eq 'Tab' || $key eq 'Down' || $key eq 'Right') {
		$self->_next_active;
		return 1;
	} elsif ($key eq 'Up' || $key eq 'Left') {
		$self->_prev_active;
		return 1;
	} elsif ($key eq 'Enter' || $key eq 'Space') {
		$self->{'_mode'} = $self->{'_active'};
		$self->_regenerate;
		$self->redraw;
		return 1;
	} elsif ($key eq 'q' || $key eq 'C-c') {
		$self->window->tickit->stop if $self->window;
		return 1;
	}

	return 0;
}

sub render_to_rb {
	my $self = shift;
	my ($rb, $rect) = @_;
	my $win = $self->window;

	$rb->eraserect($rect, Tickit::Pen->new('bg' => 'black'));
	return if ! $win;

	my $lines = $win->lines;
	my $cols = $win->cols;
	my $popup_width = _min(30, _max(22, $cols - 2));
	my $popup_left = int(($cols - $popup_width) / 2);

	$self->_render_popup($rb, $popup_left, $popup_width);
	$self->_render_text($rb, 5, _max(0, $lines - 7), $cols);
	$self->_render_status($rb, $lines - 1, $cols);

	$win->focus(0, 0);

	return;
}

sub _render_popup {
	my ($self, $rb, $left, $width) = @_;

	my $normal = Tickit::Pen->new('fg' => 'white', 'bg' => 'blue');
	my $active = Tickit::Pen->new('fg' => 'black', 'bg' => 'cyan');
	my $selected = Tickit::Pen->new('fg' => 'yellow', 'bg' => 'blue', 'b' => 1);
	my $top = '+' . ('-' x ($width - 2)) . '+';
	my @rows = (
		['paragraphs', 'paragraphs', $self->{'_counts'}->{'paragraphs'}],
		['sentences', 'sentences', $self->{'_counts'}->{'sentences'}],
		['words', 'words', $self->{'_counts'}->{'words'}],
	);

	$rb->text_at(0, $left, $top, $normal);
	for my $i (0 .. $#rows) {
		my ($id, $label, $count) = @{$rows[$i]};
		my $prefix = $self->{'_mode'} eq $id ? '*' : ' ';
		my $text = sprintf('| %s %-10s %6d %s', $prefix, $label.':', $count, '|');
		$text = substr($text, 0, $width);
		$text .= ' ' x ($width - length $text);
		my $pen = $self->{'_active'} eq $id ? $active : $normal;
		$rb->text_at($i + 1, $left, $text, $pen);
		if ($self->{'_mode'} eq $id && $self->{'_active'} ne $id) {
			$rb->text_at($i + 1, $left + 2, '*', $selected);
		}
	}
	$rb->text_at(@rows + 1, $left, $top, $normal);

	return;
}

sub _render_text {
	my ($self, $rb, $top, $height, $cols) = @_;

	return if $height <= 0 || $cols <= 0;

	my $width = _max(10, $cols - 4);
	my @wrapped = _wrap_text($self->{'_text'}, $width);
	my $start = $top + int(($height - @wrapped) / 2);
	$start = $top if $start < $top;
	my $max_line = $top + $height - 1;
	my $pen = Tickit::Pen->new('fg' => 'green', 'bg' => 'black');

	for my $i (0 .. $#wrapped) {
		my $line_no = $start + $i;
		last if $line_no > $max_line;
		my $line = $wrapped[$i];
		my $col = int(($cols - length $line) / 2);
		$col = 0 if $col < 0;
		$rb->text_at($line_no, $col, $line, $pen);
	}

	return;
}

sub _render_status {
	my ($self, $rb, $line, $cols) = @_;

	return if $line < 0 || $cols <= 0;

	my $left = '+/- count, Tab setting, Enter generator, q quit';
	my $right = 'v'.$self->{'_version'};
	my $pen = Tickit::Pen->new('fg' => 'black', 'bg' => 'white');

	$rb->erase_at($line, 0, $cols, $pen);
	if (length($right) < $cols) {
		my $left_width = $cols - length($right) - 1;
		$left = substr($left, 0, $left_width);
		$rb->text_at($line, 0, $left, $pen);
		$rb->text_at($line, $cols - length($right), $right, $pen);
	} else {
		$rb->text_at($line, 0, substr($right, 0, $cols), $pen);
	}

	return;
}

sub _change_count {
	my ($self, $delta) = @_;

	my $active = $self->{'_active'};
	my $value = $self->{'_counts'}->{$active} + $delta;
	$value = 1 if $value < 1;
	$self->{'_counts'}->{$active} = $value;
	$self->{'_mode'} = $active;
	$self->_regenerate;
	$self->redraw;

	return;
}

sub _next_active {
	my $self = shift;

	if ($self->{'_active'} eq 'paragraphs') {
		$self->{'_active'} = 'sentences';
	} elsif ($self->{'_active'} eq 'sentences') {
		$self->{'_active'} = 'words';
	} else {
		$self->{'_active'} = 'paragraphs';
	}
	$self->redraw;

	return;
}

sub _prev_active {
	my $self = shift;

	if ($self->{'_active'} eq 'paragraphs') {
		$self->{'_active'} = 'words';
	} elsif ($self->{'_active'} eq 'sentences') {
		$self->{'_active'} = 'paragraphs';
	} else {
		$self->{'_active'} = 'sentences';
	}
	$self->redraw;

	return;
}

sub _regenerate {
	my $self = shift;

	if ($self->{'_mode'} eq 'paragraphs') {
		my @paragraphs = $self->{'_lorem'}->paragraphs($self->{'_counts'}->{'paragraphs'});
		$self->{'_text'} = join "\n\n", @paragraphs;
	} elsif ($self->{'_mode'} eq 'sentences') {
		$self->{'_text'} = $self->{'_lorem'}->sentences($self->{'_counts'}->{'sentences'});
	} else {
		$self->{'_text'} = $self->{'_lorem'}->words($self->{'_counts'}->{'words'});
	}

	return;
}

sub _wrap_text {
	my ($text, $width) = @_;

	my @lines;
	foreach my $paragraph (split /\n\n+/, $text) {
		my @words = split /\s+/, $paragraph;
		my $line = '';
		foreach my $word (@words) {
			while (length $word > $width) {
				push @lines, substr($word, 0, $width, '');
			}
			if ($line eq '') {
				$line = $word;
			} elsif (length($line) + 1 + length($word) <= $width) {
				$line .= ' '.$word;
			} else {
				push @lines, $line;
				$line = $word;
			}
		}
		push @lines, $line if $line ne '';
		push @lines, '';
	}
	pop @lines if @lines && $lines[-1] eq '';

	return @lines;
}

sub _min {
	my ($x, $y) = @_;

	return $x < $y ? $x : $y;
}

sub _max {
	my ($x, $y) = @_;

	return $x > $y ? $x : $y;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

App::Lorem::Tickit::Widget - Tickit widget for lorem ipsum generator.

=head1 SYNOPSIS

 use App::Lorem::Tickit::Widget;

 my $widget = App::Lorem::Tickit::Widget->new(
         'version' => '0.01',
 );

=head1 METHODS

=head2 C<new>

 my $widget = App::Lorem::Tickit::Widget->new(%params);

Constructor.

Returns instance of object.

=head2 C<CAN_FOCUS>

 my $can_focus = $widget->CAN_FOCUS;

Returns true value.

=head2 C<cols>

 my $cols = $widget->cols;

Returns requested number of columns.

=head2 C<lines>

 my $lines = $widget->lines;

Returns requested number of lines.

=head2 C<on_key>

 my $handled = $widget->on_key($event);

Process keyboard event.

=head2 C<render_to_rb>

 $widget->render_to_rb($render_buffer, $rect);

Render widget to Tickit render buffer.

=head1 DEPENDENCIES

L<Text::Lorem>,
L<Tickit::Pen>,
L<Tickit::Widget>.

=head1 REPOSITORY

L<https://github.com/michal-josef-spacek/App-Lorem-Tickit>

=head1 AUTHOR

Michal Josef Špaček L<mailto:skim@cpan.org>

L<http://skim.cz>

=head1 LICENSE AND COPYRIGHT

© 2026 Michal Josef Špaček

BSD 2-Clause License

=head1 VERSION

0.01

=cut
