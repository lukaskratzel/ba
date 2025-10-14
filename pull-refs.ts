// Map CSL types to Hayagriva types
function mapType(cslType: string): string {
    const typeMap: Record<string, string> = {
        'paper-conference': 'conference',
        'article-journal': 'article',
        'thesis': 'thesis',
        'book': 'book',
        'chapter': 'chapter',
        'report': 'report',
    };
    return typeMap[cslType] || 'misc';
}

// Transform CSL YAML to Hayagriva YAML format
function transformToHayagriva(cslData: any): Record<string, any> {
    const result: Record<string, any> = {};
    
    for (const entry of cslData.references) {
        const citationKey = entry['citation-key'] || entry.id;
        const hayagrivaEntry: any = {
            type: mapType(entry.type),
        };

        // Title
        if (entry.title) {
            hayagrivaEntry.title = entry.title;
        }

        // Authors
        if (entry.author && Array.isArray(entry.author)) {
            hayagrivaEntry.author = entry.author.map((a: any) => {
                if (a.literal) return a.literal;
                if (a.family && a.given) return `${a.family}, ${a.given}`;
                if (a.family) return a.family;
                return String(a);
            });
        }

        // Date
        if (entry.issued && Array.isArray(entry.issued) && entry.issued[0]) {
            const date = entry.issued[0];
            if (date.year && date.month && date.day) {
                hayagrivaEntry.date = `${date.year}-${String(date.month).padStart(2, '0')}-${String(date.day).padStart(2, '0')}`;
            } else if (date.year && date.month) {
                hayagrivaEntry.date = `${date.year}-${String(date.month).padStart(2, '0')}`;
            } else if (date.year) {
                hayagrivaEntry.date = date.year;
            }
        }

        // Parent (for conference papers, etc.)
        if (entry['container-title']) {
            hayagrivaEntry.parent = [{
                type: entry.type === 'paper-conference' ? 'proceedings' : 'periodical',
                title: entry['container-title'],
            }];
        }

        // Publisher
        if (entry.publisher) {
            hayagrivaEntry.publisher = entry.publisher;
        }

        // Page range
        if (entry.page) {
            hayagrivaEntry['page-range'] = entry.page;
        }

        // DOI
        if (entry.DOI) {
            hayagrivaEntry.doi = entry.DOI;
        }

        // URL
        if (entry.URL) {
            hayagrivaEntry.url = entry.URL;
        }

        // ISBN
        if (entry.ISBN) {
            hayagrivaEntry.isbn = entry.ISBN;
        }

        // ISSN
        if (entry.ISSN) {
            hayagrivaEntry.issn = entry.ISSN;
        }

        // Volume
        if (entry.volume) {
            hayagrivaEntry.volume = entry.volume;
        }

        // Issue/Number
        if (entry.issue || entry.number) {
            hayagrivaEntry.issue = entry.issue || entry.number;
        }

        result[citationKey] = hayagrivaEntry;
    }

    return result;
}

async function main() {
    // Fetch CSL YAML from Zotero
    const ymlRsp = await fetch(
        "http://127.0.0.1:23119/better-bibtex/export?/group;id:5464579/collection;key:2A9L376B/2025 - BA Kratzel.yaml"
    );

    const ymlText = await ymlRsp.text();
    
    // Parse CSL YAML
    const cslData = Bun.YAML.parse(ymlText);
    
    // Transform to Hayagriva format
    const hayagrivaData = transformToHayagriva(cslData);
    
    // Write Hayagriva YAML
    const hayagrivaYml = Bun.YAML.stringify(hayagrivaData, null, 2);
    await Bun.write("./thesis.yml", hayagrivaYml);
    
    console.log(`✓ Transformed ${Object.keys(hayagrivaData).length} references to Hayagriva YAML format`);

    // Fetch and save BibTeX
    const bibRsp = await fetch(
        "http://127.0.0.1:23119/better-bibtex/export?/group;id:5464579/collection;key:2A9L376B/2025 - BA Kratzel.bibtex"
    );

    const bibText = await bibRsp.arrayBuffer();
    await Bun.write("./thesis.bib", bibText);
    
    console.log(`✓ Saved BibTeX file`);
}

main().catch(console.error);
