php-cs-fixer-test:
	php-cs-fixer fix --config=.php-cs-fixer.dist.php --dry-run --diff

php-cs-fixer-apply:
	php-cs-fixer fix --config=.php-cs-fixer.dist.php
