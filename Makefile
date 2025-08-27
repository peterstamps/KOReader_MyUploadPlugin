.PHONY: test update-snapshots ci

test:
	@echo "Running busted tests..."
	@busted

update-snapshots:
	@echo "Updating HTML snapshots..."
	@./scripts/update-snapshots.sh
