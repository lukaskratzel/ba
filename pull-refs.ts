import fs from "fs";

async function main() {

    const bibRsp = await fetch(
        "http://127.0.0.1:23119/better-bibtex/export?/group;id:5464579/collection;key:2A9L376B/2025 - BA Kratzel.bibtex"
    );

    const bibText = await bibRsp.arrayBuffer();
    await fs.promises.writeFile("./thesis.bib", Buffer.from(bibText));
    
    console.log(`✓ Saved BibTeX file`);
}

main().catch(console.error);
