// index.js (or worker.js)
export default {
    async fetch(request) {
        const url = new URL(request.url);

        // Check if the request path is '/'
        if (url.pathname === '/') {
            // Fetch the shell script file
            const script = await fetch('https://raw.githubusercontent.com/JonasunderscoreJones/ArchSystemSetup/refs/heads/main/syssetup.sh');
            const scriptText = await script.text();

            return new Response(scriptText, {
                headers: {
                    'Content-Type': 'text/plain', // Set the correct content type
                    'Cache-Control': 'no-store' // Optional: Prevent caching
                }
            });
        }

        if (url.pathname === '/flatpaks') {
            // Fetch the shell script file
            const script = await fetch('https://raw.githubusercontent.com/JonasunderscoreJones/ArchSystemSetup/refs/heads/main/flatpaks.txt');
            const scriptText = await script.text();

            return new Response(scriptText, {
                headers: {
                    'Content-Type': 'text/plain', // Set the correct content type
                    'Cache-Control': 'no-store' // Optional: Prevent caching
                }
            });
        }

        if (url.pathname === '/packages') {
            // Fetch the shell script file
            const script = await fetch('https://raw.githubusercontent.com/JonasunderscoreJones/ArchSystemSetup/refs/heads/main/packages.txt');
            const scriptText = await script.text();

            return new Response(scriptText, {
                headers: {
                    'Content-Type': 'text/plain', // Set the correct content type
                    'Cache-Control': 'no-store' // Optional: Prevent caching
                }
            });
        }

        return new Response('Not Found', { status: 404 });
    }
};
